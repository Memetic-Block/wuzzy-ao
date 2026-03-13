-- Wuzzy Crawler for hyper-aos
--
-- Hybrid AO process that claims crawl requests from the queue, fetches content
-- via either a HyperBEAM relay device or an off-chain content oracle, and
-- delivers documents directly to subscriber nests.
--
-- Content source modes:
--   "relay"  — uses Send({ device = 'relay@1.0', ... }) for on-chain fetch
--   "oracle" — waits for an off-chain oracle to deliver content via Deliver-Content

local json = require('json')
local manifest = require('..lib.manifest')
acl = require('..common.acl')

--- @type string  Process ID of the crawl-request-queue
crawl_request_queue = crawl_request_queue or ao.env.Process.Tags['Crawl-Request-Queue'] or 'none'

--- @type '"relay"'|'"oracle"'  How content is fetched
content_source = content_source or ao.env.Process.Tags['Content-Source'] or 'oracle'

--- @class CrawlSubscriber
--- @field nest_id      string
--- @field requested_by string
--- @field requested_at number

--- @class CrawlTask
--- @field canonical_id  string
--- @field tx_id         string
--- @field path          string
--- @field subscribers   CrawlSubscriber[]
--- @field assigned_to   string
--- @field claimed_at    number
--- @field completed_at  nil|number
--- @field retries       number
--- @field error         nil|string
--- @field status        string

--- @type CrawlTask|nil  The currently active crawl task (from Crawl-Request-Claimed)
current_task = current_task or nil

-- Update ACL Roles --
Handlers.add('Update-Roles', 'Update-Roles', function (msg)
  acl.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Update-Roles' })
  acl = acl.updateRoles(json.decode(msg.Data), acl)
  Send({ Target = msg.From, Action = 'Update-Roles-Response', Data = 'OK' })
  Send({ device = 'patch@1.0', acl = acl })
end)

-- View ACL Roles --
Handlers.add('View-Roles', 'View-Roles', function (msg)
  Send({ Target = msg.From, Action = 'View-Roles-Response', Data = json.encode(acl.state) })
end)

-- Configure --
-- Owner/admin updates crawler settings.
-- Tags: Crawl-Request-Queue (optional), Content-Source (optional: "relay"|"oracle")
Handlers.add('Configure', 'Configure', function (msg)
  acl.assertHasOneOfRole(msg.From, { 'owner', 'admin' })

  if type(msg.Tags['Crawl-Request-Queue']) == 'string' and #msg.Tags['Crawl-Request-Queue'] > 0 then
    crawl_request_queue = msg.Tags['Crawl-Request-Queue']
  end

  if msg.Tags['Content-Source'] == 'relay' or msg.Tags['Content-Source'] == 'oracle' then
    content_source = msg.Tags['Content-Source']
  end

  Send({
    Target = msg.From,
    Action = 'Configure-Response',
    Data = json.encode({
      crawl_request_queue = crawl_request_queue,
      content_source = content_source
    })
  })
  Send({
    device = 'patch@1.0',
    crawl_request_queue = crawl_request_queue,
    content_source = content_source
  })
end)

-- Poll --
-- Triggered externally (e.g., a periodic script). Sends Claim-Crawl-Request
-- to the queue. No-ops if already working on a task.
Handlers.add('Poll', 'Poll', function (msg)
  acl.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Poll' })
  assert(crawl_request_queue ~= 'none', 'No Crawl-Request-Queue configured')

  if current_task ~= nil then
    Send({
      Target = msg.From,
      Action = 'Poll-Busy',
      Data = json.encode({ canonical_id = current_task.canonical_id })
    })
    return
  end

  Send({
    Target = crawl_request_queue,
    Action = 'Claim-Crawl-Request'
  })

  Send({ Target = msg.From, Action = 'Poll-Sent', Data = 'OK' })
end)

-- Crawl-Request-Claimed --
-- Response from the queue with the claimed task. Stores the task and initiates
-- content fetch based on content_source mode.
Handlers.add('Crawl-Request-Claimed', 'Crawl-Request-Claimed', function (msg)
  if msg.From ~= crawl_request_queue then return end

  local ok, task = pcall(json.decode, msg.Data)
  if not ok or type(task) ~= 'table' then return end

  current_task = task

  Send({
    device = 'patch@1.0',
    current_task = current_task
  })

  if content_source == 'relay' then
    -- Initiate fetch via HyperBEAM relay device
    local arUrl = 'ar://' .. task.tx_id
    if task.path and #task.path > 0 then
      arUrl = arUrl .. task.path
    end
    Send({
      device = 'relay@1.0',
      Action = 'Fetch',
      URL = arUrl,
      ['Canonical-Id'] = task.canonical_id
    })
  end
  -- If content_source == 'oracle', we wait for Deliver-Content from the oracle
end)

-- No-Crawl-Requests --
-- Queue has nothing available. Informational only.
Handlers.add('No-Crawl-Requests', 'No-Crawl-Requests', function (msg)
  if msg.From ~= crawl_request_queue then return end
  -- Nothing to do — idle
end)

-- Deliver-Content --
-- Receives fetched content (from relay callback or off-chain oracle).
-- Delivers Index-Document to each subscriber nest, then marks the request
-- complete in the queue.
Handlers.add('Deliver-Content', 'Deliver-Content', function (msg)
  -- In relay mode, content comes from the relay device (msg.From may vary)
  -- In oracle mode, only owner/admin/Oracle role can deliver
  if content_source == 'oracle' then
    acl.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Oracle' })
  else
    -- Optionally, we could enforce that msg.From is the relay device ID
    -- something like acl.assertDevice(msg.From, 'relay@1.0')
    -- for now, throw if content_source isn't oracle
    assert(content_source == 'oracle', 'Content must be delivered by relay device in relay mode')
  end

  assert(current_task ~= nil, 'No active crawl task')
  assert(type(msg.Data) == 'string' and #msg.Data > 0, 'Content (Data) is required')

  local contentType = msg.Tags['Content-Type'] or 'text/html'

  -- If this is an Arweave manifest, parse it and queue sub-paths for crawling
  -- instead of delivering the raw manifest JSON to nests.
  if manifest.isManifestContentType(contentType) then
    local parsed, parseErr = manifest.parse(msg.Data)
    assert(parsed, 'Invalid manifest: ' .. (parseErr or 'unknown error'))

    local paths = manifest.enumerate(parsed)

    Send({
      Target = crawl_request_queue,
      Action = 'Discover-Crawl-Paths',
      Data = json.encode({
        tx_id = current_task.tx_id,
        paths = paths,
        subscribers = current_task.subscribers
      })
    })

    -- Mark the manifest crawl task itself as complete
    Send({
      Target = crawl_request_queue,
      Action = 'Complete-Crawl-Request',
      ['Canonical-Id'] = current_task.canonical_id
    })

    local completedId = current_task.canonical_id
    current_task = nil

    Send({
      Target = msg.From,
      Action = 'Content-Delivered',
      Data = 'OK',
      ['Canonical-Id'] = completedId
    })
    Send({ device = 'patch@1.0', current_task = current_task })
    return
  end

  local title = msg.Tags['Document-Title'] or ''
  local description = msg.Tags['Document-Description'] or ''

  -- Build the Arweave URL for the document
  local arUrl = 'ar://' .. current_task.tx_id
  if current_task.path and #current_task.path > 0 then
    arUrl = arUrl .. current_task.path
  end

  -- Deliver to each subscriber nest
  for _, subscriber in ipairs(current_task.subscribers or {}) do
    Send({
      Target = subscriber.nest_id,
      Action = 'Index-Document',
      ['Document-Url'] = arUrl,
      ['Document-Last-Crawled-At'] = tostring(msg.Timestamp),
      ['Document-Content-Type'] = contentType,
      ['Document-Title'] = title,
      ['Document-Description'] = description,
      Data = msg.Data
    })
  end

  -- Mark complete in the queue
  Send({
    Target = crawl_request_queue,
    Action = 'Complete-Crawl-Request',
    ['Canonical-Id'] = current_task.canonical_id
  })

  local completedId = current_task.canonical_id
  current_task = nil

  Send({
    Target = msg.From,
    Action = 'Content-Delivered',
    Data = 'OK',
    ['Canonical-Id'] = completedId
  })
  Send({ device = 'patch@1.0', current_task = current_task })
end)

-- Content-Failed --
-- Content fetch failed (relay error or oracle reports failure).
-- Reports failure to the queue (which handles retry/permanent-fail logic).
Handlers.add('Content-Failed', 'Content-Failed', function (msg)
  if content_source == 'oracle' then
    acl.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Oracle' })
  end

  assert(current_task ~= nil, 'No active crawl task')

  local errorMsg = msg.Tags['Error'] or msg.Data or 'Unknown error'

  Send({
    Target = crawl_request_queue,
    Action = 'Fail-Crawl-Request',
    ['Canonical-Id'] = current_task.canonical_id,
    ['Error'] = errorMsg
  })

  current_task = nil

  Send({
    Target = msg.From,
    Action = 'Content-Failure-Reported',
    Data = 'OK'
  })
  Send({ device = 'patch@1.0', current_task = current_task })
end)

-- View-State --
Handlers.add('View-State', 'View-State', function (msg)
  Send({
    Target = msg.From,
    Action = 'View-State-Response',
    Data = json.encode({
      crawl_request_queue = crawl_request_queue,
      content_source = content_source,
      current_task = current_task,
      acl = acl.state
    })
  })
end)

-- Initial state patch --
Send({
  device = 'patch@1.0',
  acl = acl,
  crawl_request_queue = crawl_request_queue,
  content_source = content_source,
  current_task = current_task
})
