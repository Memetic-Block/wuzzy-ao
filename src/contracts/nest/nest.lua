-- Wuzzy Nest for hyper-aos
--
-- Core indexing/storage process. Holds crawled documents and provides
-- document CRUD. Integrates with:
--   - Nest Registry: self-registers on init via registration code
--   - Crawl Request Queue: forwards crawl requests, auto-trusts endorsed crawlers

local json = require('json')
local utils = require('.utils')
local neturl = require('..lib.neturl')
local terms = require('..lib.terms')
local bm25 = require('..lib.bm25')
acl = require('..common.acl')

--- @class Document
--- @field SubmittedBy   string
--- @field DocumentId    string
--- @field LastCrawledAt string
--- @field Protocol      string
--- @field Domain        string
--- @field Path          string
--- @field URL           string
--- @field ContentType   string
--- @field Content       string
--- @field TermCount     number
--- @field ContentLength number
--- @field Title         string
--- @field Description   string

--- @type table<number, Document>
documents = documents or {}

--- @type integer
total_documents = total_documents or 0

--- @type integer
total_term_count = total_term_count or 0

--- @type integer
total_content_length = total_content_length or 0

--- @type number
average_document_term_length = average_document_term_length or 0

--- Inverted index: term → { documentId → term frequency }
--- @type table<string, table<string, number>>
term_index = term_index or {}

--- @type string
registration_code = registration_code or ao.env.Process.Tags['Registration-Code'] or 'none'

--- @type string
nest_registry = nest_registry or ao.env.Process.Tags['Nest-Registry'] or 'none'

--- @type string
crawl_request_queue = crawl_request_queue or ao.env.Process.Tags['Crawl-Request-Queue'] or 'none'

--- @type string
nest_creator = Owner

--- @type string
nest_id = ao.id

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

-- Index Document --
Handlers.add('Index-Document', 'Index-Document', function (msg)
  acl.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Index-Document' })

  local url = msg.Tags['Document-Url']
  assert(url, 'Missing Document-Url')
  local parsedUrl = neturl.parse(url):normalize() -- TODO -> Safely parse url
  local protocol = parsedUrl.scheme
  local domain = parsedUrl.host or parsedUrl.authority
  local path = parsedUrl.path
  if path:sub(-1) == '/' then
    path = path:sub(1, -2)
  end
  assert(protocol and domain and path, 'Invalid Document-Url: ' .. url)
  local documentId = protocol .. '://' .. domain .. path
  local lastCrawledAtStr = msg.Tags['Document-Last-Crawled-At']
  assert(type(lastCrawledAtStr) == 'string', 'Missing Document-Last-Crawled-At')
  local lastCrawledAt = lastCrawledAtStr
  assert(type(lastCrawledAt) == 'string', 'Invalid Document-Last-Crawled-At: ' .. lastCrawledAtStr)
  local contentType = msg.Tags['Document-Content-Type']
  assert(contentType, 'Missing Document-Content-Type')
  assert(type(contentType) == 'string' and contentType ~= '', 'Invalid Document-Content-Type: ' .. contentType)

  local existingDocumentIndex = nil
  local existingDocument = nil
  for i, doc in ipairs(documents) do
    if doc.DocumentId == documentId then
      existingDocumentIndex = i
      existingDocument = doc
      break
    end
  end

  assert(msg.Data and #msg.Data > 0, 'Missing Document Content (Data)')
  local termCount = terms.countTerms(msg.Data)
  local oldTermCount = existingDocument and existingDocument.TermCount or 0
  total_term_count = total_term_count + termCount - oldTermCount

  local oldContentLength = existingDocument and existingDocument.ContentLength or 0
  total_content_length = total_content_length + #msg.Data - oldContentLength

  if not existingDocument then
    total_documents = total_documents + 1
  end

  if (total_documents > 0) then
    average_document_term_length = total_term_count / total_documents
  else
    average_document_term_length = 0
  end

  -- Update inverted index: remove old entries then add new ones
  if existingDocument then
    local oldFreqs = terms.getTermFrequencies(existingDocument.Content)
    for term, _ in pairs(oldFreqs) do
      if term_index[term] then
        term_index[term][documentId] = nil
        if next(term_index[term]) == nil then
          term_index[term] = nil
        end
      end
    end
  end
  local newFreqs = terms.getTermFrequencies(msg.Data)
  for term, freq in pairs(newFreqs) do
    if not term_index[term] then
      term_index[term] = {}
    end
    term_index[term][documentId] = freq
  end

  ---@type Document
  local Document = {
    SubmittedBy = msg.From,
    DocumentId = documentId,
    LastCrawledAt = lastCrawledAt,
    Protocol = protocol,
    Domain = domain,
    Path = path,
    URL = url,
    ContentType = contentType,
    Content = msg.Data,
    ContentLength = #msg.Data,
    TermCount = termCount,
    Title = msg.Tags['Document-Title'],
    Description = msg.Tags['Document-Description']
  }

  if existingDocumentIndex then
    documents[existingDocumentIndex] = Document
  else
    table.insert(documents, Document)
  end

  Send({
    Target = msg.From,
    Action = 'Index-Document-Result',
    ['Document-Id'] = documentId,
    Data = 'OK'
  })
  Send({
    device = 'patch@1.0',
    documents = documents,
    total_documents = total_documents,
    total_term_count = total_term_count,
    total_content_length = total_content_length,
    average_document_term_length = average_document_term_length,
    term_index = term_index
  })
end)

-- Remove Document --
Handlers.add('Remove-Document', 'Remove-Document', function (msg)
  acl.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Remove-Document' })

  local documentId = msg.Tags['Document-Id']
  assert(documentId, 'Document-Id is required')
  local document = utils.find(
    function(doc) return doc.DocumentId == documentId end,
    documents
  )
  assert(document, 'Document not found')

  for i, doc in ipairs(documents) do
    if doc.DocumentId == documentId then
      table.remove(documents, i)
      break
    end
  end

  total_documents = total_documents - 1
  total_term_count = total_term_count - document.TermCount
  total_content_length = total_content_length - document.ContentLength
  if (total_documents > 0) then
    average_document_term_length = total_term_count / total_documents
  else
    average_document_term_length = 0
  end

  -- Remove document from inverted index
  local docFreqs = terms.getTermFrequencies(document.Content)
  for term, _ in pairs(docFreqs) do
    if term_index[term] then
      term_index[term][documentId] = nil
      if next(term_index[term]) == nil then
        term_index[term] = nil
      end
    end
  end

  Send({
    Target = msg.From,
    Action = 'Remove-Document-Result',
    ['Document-Id'] = documentId,
    Data = 'OK'
  })
  Send({
    device = 'patch@1.0',
    documents = documents,
    total_documents = total_documents,
    total_term_count = total_term_count,
    total_content_length = total_content_length,
    average_document_term_length = average_document_term_length,
    term_index = term_index
  })
end)

-- Request-Crawl --
-- Nest owner/admin submits Arweave TX IDs for crawling. The nest forwards the
-- request to its configured crawl-request-queue, self-authenticating as the
-- nest process.
-- Tags: TX-Id (required), Path (optional)
-- Data: Alternative batch format — newline-separated TX-Id values
Handlers.add('Request-Crawl', 'Request-Crawl', function (msg)
  acl.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Request-Crawl' })
  assert(crawl_request_queue ~= 'none', 'No Crawl-Request-Queue configured')

  local txIds = {}
  if type(msg.Tags['TX-Id']) == 'string' and #msg.Tags['TX-Id'] > 0 then
    table.insert(txIds, { tx_id = msg.Tags['TX-Id'], path = msg.Tags['Path'] or '' })
  elseif type(msg.Data) == 'string' and msg.Data ~= '' then
    for line in msg.Data:gmatch('[^\n]+') do
      local trimmed = line:match('^%s*(.-)%s*$')
      if trimmed ~= '' then
        table.insert(txIds, { tx_id = trimmed, path = '' })
      end
    end
  end
  assert(#txIds > 0, 'At least one TX-Id is required (via TX-Id tag or newline-separated Data)')

  for _, entry in ipairs(txIds) do
    Send({
      Target = crawl_request_queue,
      Action = 'Request-Crawl',
      ['TX-Id'] = entry.tx_id,
      ['Path'] = entry.path
    })
  end

  Send({
    Target = msg.From,
    Action = 'Crawl-Forwarded',
    Data = 'OK',
    ['TX-Id-Count'] = tostring(#txIds)
  })
end)

-- Crawl-Requested Response Handler --
-- When the queue acknowledges our Request-Crawl, it includes the list of
-- registered crawler IDs. We auto-grant Index-Document permission to each
-- so they can deliver content directly.
Handlers.add('Crawl-Requested', 'Crawl-Requested', function (msg)
  -- Only accept from our configured queue
  if msg.From ~= crawl_request_queue then return end

  local ok, crawlerIds = pcall(json.decode, msg.Data)
  if not ok or type(crawlerIds) ~= 'table' then return end

  for _, crawlerId in ipairs(crawlerIds) do
    if type(crawlerId) == 'string' and #crawlerId > 0 then
      -- Idempotent: grant Index-Document role
      if not acl.roles['Index-Document'] then
        acl.roles['Index-Document'] = {}
      end
      acl.roles['Index-Document'][crawlerId] = true
    end
  end

  Send({ device = 'patch@1.0', acl = acl })
end)

-- Search --
Handlers.add('Search', 'Search', function (msg)
  local query = msg.Data
  assert(type(query) == 'string' and query ~= '', 'Search query is required in Data')

  local results = bm25.search(
    query,
    term_index,
    documents,
    total_documents,
    average_document_term_length
  )

  -- Enrich results with document metadata
  local docMap = {}
  for _, doc in ipairs(documents) do
    docMap[doc.DocumentId] = doc
  end

  local enriched = {}
  for _, result in ipairs(results) do
    local doc = docMap[result.DocumentId]
    enriched[#enriched + 1] = {
      DocumentId  = result.DocumentId,
      Score       = result.Score,
      Title       = doc and doc.Title or nil,
      Description = doc and doc.Description or nil,
      URL         = doc and doc.URL or nil,
      Domain      = doc and doc.Domain or nil
    }
  end

  Send({
    Target = msg.From,
    Action = 'Search-Result',
    Data = json.encode(enriched)
  })
end)

-- Optional Registration with Nest Registry --
if nest_registry ~= 'none' then
  Send({
    Target = nest_registry,
    Action = 'Register-Nest',
    ['Registration-Code'] = registration_code,
    Data = json.encode({ acl = acl, owner = Owner })
  })
end

-- Initial state patch --
Send({
  device = 'patch@1.0',
  acl = acl,
  documents = documents,
  total_documents = total_documents,
  total_term_count = total_term_count,
  total_content_length = total_content_length,
  average_document_term_length = average_document_term_length,
  term_index = term_index,
  registration_code = registration_code,
  nest_registry = nest_registry,
  crawl_request_queue = crawl_request_queue,
  nest_creator = nest_creator,
  nest_id = nest_id
})
