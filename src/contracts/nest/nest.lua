-- Wuzzy Nest Registry for hyper-aos
local json = require('json')
local utils = require('.utils')
local neturl = require('..lib.neturl')
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

--- @type string
registration_code = registration_code or ao.env.Process.Tags['Registration-Code'] or 'none'

--- @type string
nest_registry = nest_registry or ao.env.Process.Tags['Nest-Registry'] or 'none'

--- @class Crawler
--- @field CrawlerId string
--- @field Owner     string
--- @type table<number, Crawler>
crawlers = crawlers or {}

--- @class CrawlRequest
--- @field URL         string
--- @field RequestedBy string
--- @field Status      CrawlRequestStatus

--- @alias CrawlRequestStatus
---| '"queued"'      # CrawlRequest is queued and waiting to be processed
---| '"in_progress"' # CrawlRequest is currently being processed by one or more crawlers
---| '"completed"'   # CrawlRequest has been completed and the document has been indexed

--- @type table<number, CrawlRequest>
crawl_requests = crawl_requests or {}

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
  local termCount = select(2, string.gsub(msg.Data, '[^%s%p]+', ''))
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
    average_document_term_length = average_document_term_length
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
    average_document_term_length = average_document_term_length
  })
end)

-- Add Crawler --
Handlers.add('Add-Crawler', 'Add-Crawler', function (msg)
  acl.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Add-Crawler' })
  assert(type(msg.Tags['Crawler-Id']) == 'string', 'Crawler-Id is required')
  local existingCrawler = utils.find(
    function(crawler) return crawler.CrawlerId == msg.Tags['Crawler-Id'] end,
    crawlers
  )
  assert(not existingCrawler, 'Crawler-Id already exists')

  table.insert(crawlers, {
    CrawlerId = msg.Tags['Crawler-Id'],
    Owner = msg.From
  })
  acl.updateRoles({ Grant = { [msg.Tags['Crawler-Id']] = { 'Index-Document' } } })

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
    if crawler.CrawlerId == msg.Tags['Crawler-Id'] then
      existingCrawlerIndex = i
      existingCrawler = crawler
      break
    end
  end
  assert(existingCrawler, 'Crawler-Id does not exist')

  table.remove(crawlers, existingCrawlerIndex)
  acl.updateRoles({ Revoke = { [msg.Tags['Crawler-Id']] = { 'Index-Document' } } })

  Send({
    Target = msg.From,
    Action = 'Crawler-Removed',
    Data = 'OK',
    ['Crawler-Id'] = msg.Tags['Crawler-Id']
  })
  Send({ device = 'patch@1.0', crawlers = crawlers })
end)

-- Request Crawl --
Handlers.add('Request-Crawl', 'Request-Crawl', function (msg)
  assert(type(msg.Tags['URL']) == 'string', 'URL is required')

  table.insert(crawl_requests, { URL = msg.Tags['URL'], RequestedBy = msg.From })

  Send({ Target = msg.From, Action = 'Crawl-Requested', Data = 'OK', URL = msg.Tags['URL'] })
  Send({ device = 'patch@1.0', crawl_requests = crawl_requests })
end)

-- Cron --
Handlers.add('Cron', 'Cron', function (msg)
  acl.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Cron' })

  if #crawl_requests > 0 then
    Send({ Target = crawlers[math.random(1, #crawlers)].CrawlerId, Action = 'Crawl', URL = crawl_requests[1].URL })
    crawl_requests[1].Status = 'in_progress'
    Send({ device = 'patch@1.0', crawl_requests = crawl_requests })
  end
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
  registration_code = registration_code,
  nest_registry = nest_registry,
  crawlers = crawlers,
  crawl_requests = crawl_requests
})
