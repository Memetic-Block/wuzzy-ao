-- Wuzzy Crawl Request Queue for hyper-aos
--
-- Coordinates crawl work between nests and crawlers.
-- Deduplicates by canonical_id (tx_id + path). Multiple nests requesting the
-- same target are collapsed into a single work item with a subscribers list.
-- Content never flows through the queue — crawlers deliver directly to nests.

local json = require('json')
local utils = require('.utils')
acl = require('..common.acl')

--- @class Crawler
--- @field crawler_id string
--- @field owner      string

--- @type table<number, Crawler>
crawlers = crawlers or {}

--- @class CrawlSubscriber
--- @field nest_id      string
--- @field requested_by string
--- @field requested_at number

--- @class CrawlRequest
--- @field canonical_id  string         # tx_id .. path — unique dedup key
--- @field tx_id         string         # Arweave transaction ID
--- @field path          string         # Path within a manifest (empty string if root)
--- @field subscribers   CrawlSubscriber[]
--- @field assigned_to   nil|string
--- @field claimed_at    nil|number
--- @field completed_at  nil|number
--- @field retries       number
--- @field error         nil|string
--- @field status        CrawlRequestStatus

--- @alias CrawlRequestStatus
---| '"queued"'      # Waiting to be claimed by a crawler
---| '"in_progress"' # Currently being processed by a crawler
---| '"completed"'   # Document delivered to all subscriber nests
---| '"failed"'      # Failed after MAX_RETRIES attempts

--- @type table<number, CrawlRequest>
crawl_requests = crawl_requests or {}

--- Lookup table: canonical_id -> index in crawl_requests for O(1) dedup
--- @type table<string, number>
crawl_index = crawl_index or {}

--- Default stale timeout: 5 minutes (in milliseconds)
STALE_TIMEOUT = STALE_TIMEOUT or 5 * 60 * 1000

--- Maximum automatic retries before marking failed
MAX_RETRIES = MAX_RETRIES or 3

--- Minimum age (ms) of a completed request before allowing re-crawl
RECRAWL_AFTER = RECRAWL_AFTER or 24 * 60 * 60 * 1000

--- @type string  Process ID of the nest-registry that vouches for nests
nest_registry = nest_registry or ao.env.Process.Tags['Nest-Registry'] or 'none'

--- Set of valid nest IDs (populated by the nest-registry via notifications)
--- @type table<string, true>
registered_nests = registered_nests or {}

-- Rebuild crawl_index from crawl_requests (idempotent, safe after reload)
local function rebuildIndex()
  crawl_index = {}
  for i, r in ipairs(crawl_requests) do
    crawl_index[r.canonical_id] = i
  end
end
rebuildIndex()

-- Compute canonical_id from tx_id and optional path
local function canonicalId(tx_id, pathStr)
  pathStr = pathStr or ''
  if pathStr ~= '' and pathStr:sub(1, 1) ~= '/' then
    pathStr = '/' .. pathStr
  end
  -- Strip trailing slash for consistency
  if pathStr:sub(-1) == '/' then
    pathStr = pathStr:sub(1, -2)
  end
  return tx_id .. pathStr
end

-- Return an array of crawler_id strings
local function crawlerIds()
  local ids = {}
  for _, c in ipairs(crawlers) do
    table.insert(ids, c.crawler_id)
  end
  return ids
end

-- Update ACL Roles --
Handlers.add('Update-Roles', 'Update-Roles', function (msg)
  acl.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Update-Roles' })
  acl = acl.updateRoles(require('json').decode(msg.Data), acl)
  Send({ Target = msg.From, Action = 'Update-Roles-Response', Data = 'OK' })
  Send({ device = 'patch@1.0', acl = acl })
end)

-- View ACL Roles --
Handlers.add('View-Roles', 'View-Roles', function (msg)
  Send({ Target = msg.From, Action = 'View-Roles-Response', Data = json.encode(acl.state) })
end)

-- Add Crawler --
Handlers.add('Add-Crawler', 'Add-Crawler', function (msg)
  acl.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Add-Crawler' })
  assert(type(msg.Tags['Crawler-Id']) == 'string', 'Crawler-Id is required')
  local existingCrawler = utils.find(
    function(crawler) return crawler.crawler_id == msg.Tags['Crawler-Id'] end,
    crawlers
  )
  assert(not existingCrawler, 'Crawler-Id already exists')

  table.insert(crawlers, {
    crawler_id = msg.Tags['Crawler-Id'],
    owner = msg.From
  })

  Send({
    Target = msg.From,
    Action = 'Crawler-Added',
    Data = 'OK',
    ['Crawler-Id'] = msg.Tags['Crawler-Id']
  })
  Send({ device = 'patch@1.0', crawlers = crawlers })
end)

-- Remove Crawler --
Handlers.add('Remove-Crawler', 'Remove-Crawler', function (msg)
  acl.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Remove-Crawler' })
  assert(type(msg.Tags['Crawler-Id']) == 'string', 'Crawler-Id is required')
  local existingCrawlerIndex = nil
  local existingCrawler = nil
  for i, crawler in ipairs(crawlers) do
    if crawler.crawler_id == msg.Tags['Crawler-Id'] then
      existingCrawlerIndex = i
      existingCrawler = crawler
      break
    end
  end
  assert(existingCrawler, 'Crawler-Id does not exist')

  table.remove(crawlers, existingCrawlerIndex)

  Send({
    Target = msg.From,
    Action = 'Crawler-Removed',
    Data = 'OK',
    ['Crawler-Id'] = msg.Tags['Crawler-Id']
  })
  Send({ device = 'patch@1.0', crawlers = crawlers })
end)

-- List Crawlers (public) --
Handlers.add('List-Crawlers', 'List-Crawlers', function (msg)
  Send({
    Target = msg.From,
    Action = 'List-Crawlers-Response',
    Data = json.encode(crawlerIds())
  })
end)

-- Notify-Nest-Registered --
-- Sent by the nest-registry when a nest is registered.
Handlers.add('Notify-Nest-Registered', 'Notify-Nest-Registered', function (msg)
  assert(msg.From == nest_registry, 'Only the configured nest-registry can notify')
  local nestId = msg.Tags['Nest-Id']
  assert(type(nestId) == 'string' and #nestId > 0, 'Nest-Id tag is required')

  registered_nests[nestId] = true

  Send({ Target = msg.From, Action = 'Notify-Nest-Registered-Ack', Data = 'OK', ['Nest-Id'] = nestId })
  Send({ device = 'patch@1.0', registered_nests = registered_nests })
end)

-- Notify-Nest-Unregistered --
-- Sent by the nest-registry when one or more nests are unregistered.
-- Data: JSON array of nest IDs.
Handlers.add('Notify-Nest-Unregistered', 'Notify-Nest-Unregistered', function (msg)
  assert(msg.From == nest_registry, 'Only the configured nest-registry can notify')
  local ok, nestIds = pcall(json.decode, msg.Data)
  assert(ok and type(nestIds) == 'table', 'Data must be a JSON array of nest IDs')

  for _, nestId in ipairs(nestIds) do
    registered_nests[nestId] = nil
  end

  Send({ Target = msg.From, Action = 'Notify-Nest-Unregistered-Ack', Data = 'OK' })
  Send({ device = 'patch@1.0', registered_nests = registered_nests })
end)

-- Request Crawl --
-- Open to any AO process. The sender IS the nest (Nest-Id must equal msg.From).
-- Accepts TX-Id tag (required) + optional Path tag.
-- If a queued/in_progress entry already exists for the canonical_id, the sender
-- is appended to subscribers (dedup). If the entry is completed and older than
-- RECRAWL_AFTER, it is re-queued.
Handlers.add('Request-Crawl', 'Request-Crawl', function (msg)
  -- Validate the sender is a registered nest
  local nestId = msg.From
  assert(registered_nests[nestId], 'Only registered nests can request crawls')

  local txId = msg.Tags['TX-Id']
  assert(type(txId) == 'string' and #txId > 0, 'TX-Id tag is required')
  local pathStr = msg.Tags['Path'] or ''

  local cid = canonicalId(txId, pathStr)

  -- Check for existing entry
  local existingIdx = crawl_index[cid]
  local existing = existingIdx and crawl_requests[existingIdx] or nil

  if existing then
    -- Already have an entry for this canonical_id
    if existing.status == 'queued' or existing.status == 'in_progress' then
      -- Append subscriber if not already present
      local alreadySubscribed = false
      for _, sub in ipairs(existing.subscribers) do
        if sub.nest_id == nestId then
          alreadySubscribed = true
          break
        end
      end
      if not alreadySubscribed then
        table.insert(existing.subscribers, {
          nest_id = nestId,
          requested_by = nestId,
          requested_at = msg.Timestamp
        })
      end

      Send({
        Target = msg.From,
        Action = 'Crawl-Requested',
        Data = json.encode(crawlerIds()),
        ['Canonical-Id'] = cid,
        ['Status'] = existing.status
      })
      Send({ device = 'patch@1.0', crawl_requests = crawl_requests })
      return
    elseif existing.status == 'completed' then
      -- Re-crawl if old enough
      if existing.completed_at
        and (msg.Timestamp - existing.completed_at) < RECRAWL_AFTER
      then
        Send({
          Target = msg.From,
          Action = 'Crawl-Already-Completed',
          Data = json.encode(crawlerIds()),
          ['Canonical-Id'] = cid
        })
        return
      end
      -- Reset for re-crawl
      existing.status = 'queued'
      existing.assigned_to = nil
      existing.claimed_at = nil
      existing.completed_at = nil
      existing.retries = 0
      existing.error = nil
      existing.subscribers = {{
        nest_id = nestId,
        requested_by = nestId,
        requested_at = msg.Timestamp
      }}

      Send({
        Target = msg.From,
        Action = 'Crawl-Requested',
        Data = json.encode(crawlerIds()),
        ['Canonical-Id'] = cid,
        ['Status'] = 'queued'
      })
      Send({ device = 'patch@1.0', crawl_requests = crawl_requests })
      return
    elseif existing.status == 'failed' then
      -- Allow retry of failed requests
      existing.status = 'queued'
      existing.assigned_to = nil
      existing.claimed_at = nil
      existing.completed_at = nil
      existing.retries = 0
      existing.error = nil
      existing.subscribers = {{
        nest_id = nestId,
        requested_by = nestId,
        requested_at = msg.Timestamp
      }}

      Send({
        Target = msg.From,
        Action = 'Crawl-Requested',
        Data = json.encode(crawlerIds()),
        ['Canonical-Id'] = cid,
        ['Status'] = 'queued'
      })
      Send({ device = 'patch@1.0', crawl_requests = crawl_requests })
      return
    end
  end

  -- New crawl request
  local request = {
    canonical_id = cid,
    tx_id = txId,
    path = pathStr,
    subscribers = {{
      nest_id = nestId,
      requested_by = nestId,
      requested_at = msg.Timestamp
    }},
    assigned_to = nil,
    claimed_at = nil,
    completed_at = nil,
    retries = 0,
    error = nil,
    status = 'queued'
  }
  table.insert(crawl_requests, request)
  crawl_index[cid] = #crawl_requests

  Send({
    Target = msg.From,
    Action = 'Crawl-Requested',
    Data = json.encode(crawlerIds()),
    ['Canonical-Id'] = cid,
    ['Status'] = 'queued'
  })
  Send({ device = 'patch@1.0', crawl_requests = crawl_requests })
end)

-- Claim Crawl Request --
-- Only registered crawlers may claim. Returns the first queued request with
-- full subscriber list so the crawler knows which nests to deliver to.
Handlers.add('Claim-Crawl-Request', 'Claim-Crawl-Request', function (msg)
  assert(
    utils.find(function(c) return c.crawler_id == msg.From end, crawlers),
    'Only registered crawlers can claim crawl requests'
  )

  local request = nil
  for _, r in ipairs(crawl_requests) do
    if r.status == 'queued' then
      request = r
      break
    end
  end

  if not request then
    Send({ Target = msg.From, Action = 'No-Crawl-Requests', Data = 'OK' })
    return
  end

  request.status = 'in_progress'
  request.assigned_to = msg.From
  request.claimed_at = msg.Timestamp

  Send({
    Target = msg.From,
    Action = 'Crawl-Request-Claimed',
    Data = json.encode(request)
  })
  Send({ device = 'patch@1.0', crawl_requests = crawl_requests })
end)

-- Complete Crawl Request --
-- Called by the crawler after it has delivered content directly to all
-- subscriber nests. Marks the request as completed. No document payload.
Handlers.add('Complete-Crawl-Request', 'Complete-Crawl-Request', function (msg)
  assert(
    utils.find(function(c) return c.crawler_id == msg.From end, crawlers),
    'Only registered crawlers can complete crawl requests'
  )
  local cid = msg.Tags['Canonical-Id']
  assert(type(cid) == 'string' and #cid > 0, 'Canonical-Id tag is required')

  local idx = crawl_index[cid]
  assert(idx and crawl_requests[idx], 'Crawl request not found: ' .. cid)
  local request = crawl_requests[idx]
  assert(
    request.status == 'in_progress',
    'Can only complete in_progress requests (current: ' .. request.status .. ')'
  )
  assert(request.assigned_to == msg.From, 'Only the assigned crawler can complete this request')

  request.status = 'completed'
  request.completed_at = msg.Timestamp

  Send({
    Target = msg.From,
    Action = 'Crawl-Request-Completed',
    Data = 'OK',
    ['Canonical-Id'] = cid
  })
  Send({ device = 'patch@1.0', crawl_requests = crawl_requests })
end)

-- Fail Crawl Request --
-- Called by the crawler when content fetch fails. Auto-requeues if retries
-- remain, otherwise marks as failed permanently.
Handlers.add('Fail-Crawl-Request', 'Fail-Crawl-Request', function (msg)
  assert(
    utils.find(function(c) return c.crawler_id == msg.From end, crawlers),
    'Only registered crawlers can fail crawl requests'
  )
  local cid = msg.Tags['Canonical-Id']
  assert(type(cid) == 'string' and #cid > 0, 'Canonical-Id tag is required')

  local idx = crawl_index[cid]
  assert(idx and crawl_requests[idx], 'Crawl request not found: ' .. cid)
  local request = crawl_requests[idx]
  assert(
    request.status == 'in_progress',
    'Can only fail in_progress requests (current: ' .. request.status .. ')'
  )
  assert(request.assigned_to == msg.From, 'Only the assigned crawler can fail this request')

  request.retries = (request.retries or 0) + 1
  request.error = msg.Tags['Error'] or msg.Data or 'Unknown error'

  if request.retries < MAX_RETRIES then
    -- Re-queue for another attempt
    request.status = 'queued'
    request.assigned_to = nil
    request.claimed_at = nil

    Send({
      Target = msg.From,
      Action = 'Crawl-Request-Requeued',
      Data = 'OK',
      ['Canonical-Id'] = cid,
      ['Retries'] = tostring(request.retries)
    })
  else
    -- Permanently failed
    request.status = 'failed'

    Send({
      Target = msg.From,
      Action = 'Crawl-Request-Failed',
      Data = 'OK',
      ['Canonical-Id'] = cid,
      ['Retries'] = tostring(request.retries)
    })
  end

  Send({ device = 'patch@1.0', crawl_requests = crawl_requests })
end)

-- Discover Crawl Paths --
-- Called by a crawler when delivered content is an Arweave manifest.
-- Queues each sub-path as a new crawl request, carrying over the original
-- subscribers so the actual content eventually reaches subscriber nests.
-- Data: JSON { tx_id: string, paths: [{path, id}], subscribers: CrawlSubscriber[] }
Handlers.add('Discover-Crawl-Paths', 'Discover-Crawl-Paths', function (msg)
  assert(
    utils.find(function(c) return c.crawler_id == msg.From end, crawlers),
    'Only registered crawlers can discover crawl paths'
  )

  local ok, payload = pcall(json.decode, msg.Data)
  assert(ok and type(payload) == 'table', 'Data must be valid JSON')
  assert(type(payload.tx_id) == 'string' and #payload.tx_id > 0, 'tx_id is required')
  assert(type(payload.paths) == 'table' and #payload.paths > 0, 'paths array is required')
  assert(type(payload.subscribers) == 'table' and #payload.subscribers > 0, 'subscribers array is required')

  local queued = 0
  -- Collect unique subscriber nest IDs to notify
  local nestsToNotify = {}

  for _, pathEntry in ipairs(payload.paths) do
    assert(type(pathEntry.path) == 'string', 'each path entry must have a path string')
    local cid = canonicalId(payload.tx_id, pathEntry.path)

    local existingIdx = crawl_index[cid]
    local existing = existingIdx and crawl_requests[existingIdx] or nil

    if existing then
      if existing.status == 'queued' or existing.status == 'in_progress' then
        -- Append any new subscribers
        for _, sub in ipairs(payload.subscribers) do
          local alreadySubscribed = false
          for _, existingSub in ipairs(existing.subscribers) do
            if existingSub.nest_id == sub.nest_id then
              alreadySubscribed = true
              break
            end
          end
          if not alreadySubscribed then
            table.insert(existing.subscribers, sub)
          end
        end
      elseif existing.status == 'completed' then
        if existing.completed_at
          and (msg.Timestamp - existing.completed_at) < RECRAWL_AFTER
        then
          -- Still fresh, skip
          goto continue
        end
        -- Re-queue stale completed entry
        existing.status = 'queued'
        existing.assigned_to = nil
        existing.claimed_at = nil
        existing.completed_at = nil
        existing.retries = 0
        existing.error = nil
        existing.subscribers = {}
        for _, sub in ipairs(payload.subscribers) do
          table.insert(existing.subscribers, sub)
        end
        queued = queued + 1
      elseif existing.status == 'failed' then
        -- Retry failed entry
        existing.status = 'queued'
        existing.assigned_to = nil
        existing.claimed_at = nil
        existing.completed_at = nil
        existing.retries = 0
        existing.error = nil
        existing.subscribers = {}
        for _, sub in ipairs(payload.subscribers) do
          table.insert(existing.subscribers, sub)
        end
        queued = queued + 1
      end
    else
      -- New crawl request for this sub-path
      local request = {
        canonical_id = cid,
        tx_id = payload.tx_id,
        path = pathEntry.path,
        subscribers = {},
        assigned_to = nil,
        claimed_at = nil,
        completed_at = nil,
        retries = 0,
        error = nil,
        status = 'queued'
      }
      for _, sub in ipairs(payload.subscribers) do
        table.insert(request.subscribers, sub)
      end
      table.insert(crawl_requests, request)
      crawl_index[cid] = #crawl_requests
      queued = queued + 1
    end

    -- Track nests to notify
    for _, sub in ipairs(payload.subscribers) do
      nestsToNotify[sub.nest_id] = true
    end

    ::continue::
  end

  -- Notify each unique subscriber nest so they can update crawler ACLs
  local cids = crawlerIds()
  for nestId, _ in pairs(nestsToNotify) do
    Send({
      Target = nestId,
      Action = 'Crawl-Requested',
      Data = json.encode(cids)
    })
  end

  Send({
    Target = msg.From,
    Action = 'Discover-Crawl-Paths-Response',
    Data = json.encode({ queued = queued }),
    ['TX-Id'] = payload.tx_id
  })
  Send({ device = 'patch@1.0', crawl_requests = crawl_requests })
end)

-- Reclaim Stale Crawl Requests --
Handlers.add('Reclaim-Stale', 'Reclaim-Stale', function (msg)
  acl.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Reclaim-Stale' })

  local timeout = tonumber(msg.Tags['Timeout']) or STALE_TIMEOUT
  local reclaimed = 0

  for _, r in ipairs(crawl_requests) do
    if r.status == 'in_progress'
      and r.claimed_at
      and (msg.Timestamp - r.claimed_at) > timeout
    then
      r.status = 'queued'
      r.assigned_to = nil
      r.claimed_at = nil
      reclaimed = reclaimed + 1
    end
  end

  Send({
    Target = msg.From,
    Action = 'Stale-Reclaimed',
    Data = 'OK',
    ['Reclaimed-Count'] = tostring(reclaimed)
  })
  if reclaimed > 0 then
    Send({ device = 'patch@1.0', crawl_requests = crawl_requests })
  end
end)

-- View State (public) --
Handlers.add('View-State', 'View-State', function (msg)
  Send({
    Target = msg.From,
    Action = 'View-State-Response',
    Data = json.encode({
      crawlers = crawlers,
      crawl_requests = crawl_requests,
      registered_nests = registered_nests,
      nest_registry = nest_registry,
      acl = acl.state,
      STALE_TIMEOUT = STALE_TIMEOUT,
      MAX_RETRIES = MAX_RETRIES,
      RECRAWL_AFTER = RECRAWL_AFTER
    })
  })
end)

-- Initial state patch --
Send({
  device = 'patch@1.0',
  acl = acl,
  crawlers = crawlers,
  crawl_requests = crawl_requests,
  registered_nests = registered_nests,
  nest_registry = nest_registry
})
