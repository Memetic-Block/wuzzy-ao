-- Wuzzy Nest for AO Legacynet

WuzzyNest = {
  Version = '0.0.1-legacynet',
  State = {
    --- @type table<number, {
    ---   SubmittedBy: string,
    ---   DocumentId: string,
    ---   LastCrawledAt: string,
    ---   Protocol: string,
    ---   Domain: string,
    ---   Path: string,
    ---   URL: string,
    ---   ContentType: string,
    ---   Content: string,
    ---   TermCount: number,
    ---   ContentLength: number,
    ---   Title: string,
    ---   Description: string,
    --- }>
    Documents = {},

    --- @type number
    TotalDocuments = 0,

    --- @type number
    TotalTermCount = 0,

    --- @type number
    TotalContentLength = 0,

    --- @type number
    AverageDocumentTermLength = 0,

    --- @type table<number, {
    ---   CrawlerId: string,
    ---   Creator: string,
    ---   Owner: string,
    ---   Name: string,
    --- }>
    Crawlers = {},

    --- @type number
    --- Round-robin index for crawler selection
    NextCrawlerIndex = 1,

    --- @type table<string, {
    ---   RequesterId: string,
    ---   CrawlerId: string,
    ---   RequestedAt: number,
    --- }>
    --- Pending crawl requests keyed by URL for tracking
    PendingCrawlRequests = {}
  }
}

local json = require('json')
local utils = require('.common.utils')
local neturl = require('.lib.neturl')
local ACL = require('.common.acl')
require('.common.handlers.acl')(ACL)

-- Helper: Parse and normalize a URL, returning components and normalized form
--- @param url string
--- @return { protocol: string, domain: string, path: string, normalizedUrl: string }
local function parseAndNormalizeUrl(url)
  assert(type(url) == 'string' and url ~= '', 'Missing URL')
  local parsedUrl = neturl.parse(url):normalize()
  local protocol = parsedUrl.scheme
  local domain = parsedUrl.host or parsedUrl.authority
  local path = parsedUrl.path
  if path and path:sub(-1) == '/' then
    path = path:sub(1, -2)
  end
  assert(protocol and domain and path, 'Invalid URL: ' .. url)
  local normalizedUrl = protocol .. '://' .. domain .. path
  return {
    protocol = protocol,
    domain = domain,
    path = path,
    normalizedUrl = normalizedUrl
  }
end

-- Helper: Find a document by ID, returning index and document
--- @param documentId string
--- @return number|nil, table|nil
local function findDocumentByIdWithIndex(documentId)
  for i, doc in ipairs(WuzzyNest.State.Documents) do
    if doc.DocumentId == documentId then
      return i, doc
    end
  end
  return nil, nil
end

-- Helper: Update document statistics when adding/updating a document
--- @param content string
--- @param existingDocument table|nil
--- @return { termCount: number, contentLength: number }
local function updateDocumentStats(content, existingDocument)
  local termCount = select(2, string.gsub(content, '[^%s%p]+', ''))
  local oldTermCount = existingDocument and existingDocument.TermCount or 0
  WuzzyNest.State.TotalTermCount =
    WuzzyNest.State.TotalTermCount + termCount - oldTermCount

  local contentLength = #content
  local oldContentLength = existingDocument and existingDocument.ContentLength or 0
  WuzzyNest.State.TotalContentLength =
    WuzzyNest.State.TotalContentLength + contentLength - oldContentLength

  if not existingDocument then
    WuzzyNest.State.TotalDocuments = WuzzyNest.State.TotalDocuments + 1
  end

  if WuzzyNest.State.TotalDocuments > 0 then
    WuzzyNest.State.AverageDocumentTermLength =
      WuzzyNest.State.TotalTermCount / WuzzyNest.State.TotalDocuments
  else
    WuzzyNest.State.AverageDocumentTermLength = 0
  end

  return {
    termCount = termCount,
    contentLength = contentLength
  }
end

-- Helper: Create and upsert a document, returning the documentId
--- @param params { submittedBy: string, url: string, lastCrawledAt: string, contentType: string, content: string, title: string|nil, description: string|nil }
--- @return string documentId
local function upsertDocument(params)
  local parsed = parseAndNormalizeUrl(params.url)
  local documentId = parsed.normalizedUrl

  local existingDocumentIndex, existingDocument = findDocumentByIdWithIndex(documentId)
  local stats = updateDocumentStats(params.content, existingDocument)

  local doc = {
    SubmittedBy = params.submittedBy,
    DocumentId = documentId,
    LastCrawledAt = params.lastCrawledAt,
    Protocol = parsed.protocol,
    Domain = parsed.domain,
    Path = parsed.path,
    URL = params.url,
    ContentType = params.contentType,
    Content = params.content,
    ContentLength = stats.contentLength,
    TermCount = stats.termCount,
    Title = params.title,
    Description = params.description
  }

  if existingDocumentIndex then
    WuzzyNest.State.Documents[existingDocumentIndex] = doc
  else
    table.insert(WuzzyNest.State.Documents, doc)
  end

  return documentId
end

Handlers.add('Index-Document', 'Index-Document', function (msg)
  ACL.utils.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Index-Document' })

  local url = msg.Tags['Document-URL']
  assert(url, 'Missing Document-URL')

  local lastCrawledAt = msg.Tags['Document-Last-Crawled-At']
  assert(type(lastCrawledAt) == 'string', 'Missing Document-Last-Crawled-At')

  local contentType = msg.Tags['Document-Content-Type']
  assert(type(contentType) == 'string' and contentType ~= '', 'Missing or invalid Document-Content-Type')

  assert(msg.Data and #msg.Data > 0, 'Missing Document Content')

  local documentId = upsertDocument({
    submittedBy = msg.From,
    url = url,
    lastCrawledAt = lastCrawledAt,
    contentType = contentType,
    content = msg.Data,
    title = msg.Tags['Document-Title'],
    description = msg.Tags['Document-Description']
  })

  -- Notify original requester if this was a queued crawl request
  local pendingRequest = WuzzyNest.State.PendingCrawlRequests[documentId]
  if pendingRequest then
    ao.send({
      Target = pendingRequest.RequesterId,
      Action = 'Crawl-Completed',
      ['Document-Id'] = documentId,
      ['URL'] = url,
      ['Crawler-Id'] = msg.From,
      Data = 'OK'
    })
    WuzzyNest.State.PendingCrawlRequests[documentId] = nil
  end

  ao.send({
    Target = msg.From,
    Action = 'Index-Document-Result',
    ['Document-Id'] = documentId,
    Data = 'OK'
  })
end)

Handlers.add('Bulk-Index-Document', 'Bulk-Index-Document', function (msg)
  ACL.utils.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Index-Document' })

  assert(msg.Data and #msg.Data > 0, 'Missing Documents Data')
  local documents = json.decode(msg.Data)
  assert(type(documents) == 'table', 'Documents must be a JSON array')

  local indexed = {}
  local errors = {}

  for i, docData in ipairs(documents) do
    local ok, err = pcall(function()
      assert(type(docData.URL) == 'string', 'Missing URL')
      assert(type(docData.Content) == 'string' and #docData.Content > 0, 'Missing Content')
      assert(type(docData.LastCrawledAt) == 'string', 'Missing LastCrawledAt')
      assert(type(docData.ContentType) == 'string', 'Missing ContentType')

      local documentId = upsertDocument({
        submittedBy = msg.From,
        url = docData.URL,
        lastCrawledAt = docData.LastCrawledAt,
        contentType = docData.ContentType,
        content = docData.Content,
        title = docData.Title,
        description = docData.Description
      })

      table.insert(indexed, documentId)
    end)

    if not ok then
      table.insert(errors, { Index = i, Error = err })
    end
  end

  ao.send({
    Target = msg.From,
    Action = 'Bulk-Index-Document-Result',
    Data = json.encode({
      Indexed = indexed,
      IndexedCount = #indexed,
      Errors = errors,
      ErrorCount = #errors
    })
  })
end)

Handlers.add('Remove-Document', 'Remove-Document', function (msg)
  ACL.utils.assertHasOneOfRole(
    msg.From,
    { 'owner', 'admin', 'Remove-Document' }
  )

  local documentId = msg.Tags['Document-Id']
  assert(documentId, 'Document-Id is required')
  local existingIndex, existingDocument = findDocumentByIdWithIndex(documentId)
  assert(existingDocument, 'Document not found')

  table.remove(WuzzyNest.State.Documents, existingIndex)
  WuzzyNest.State.TotalDocuments = WuzzyNest.State.TotalDocuments - 1

  ao.send({
    Target = msg.From,
    Action = 'Remove-Document-Result',
    ['Document-Id'] = documentId,
    Data = 'OK'
  })
end)

-- Search handler - STUB: returns all documents (no ranking/filtering)
-- TODO: Port search modules (simple, bm25) for full search functionality
Handlers.add('Search', 'Search', function (msg)
  local query = msg.Tags['Query']
  assert(type(query) == 'string' and query ~= '', 'Missing Search Query')
  local searchType = msg.Tags['Search-Type'] or 'simple'

  -- STUB: Return all documents as hits (no actual search/ranking)
  local hits = {}
  for _, doc in ipairs(WuzzyNest.State.Documents) do
    table.insert(hits, {
      DocumentId = doc.DocumentId,
      URL = doc.URL,
      Title = doc.Title,
      Description = doc.Description,
      Score = 1
    })
  end

  ao.send({
    Target = msg.From,
    Action = 'Search-Result',
    Data = json.encode({
      SearchType = searchType,
      Hits = hits,
      TotalCount = #hits
    })
  })
end)

Handlers.add('Add-Crawler', 'Add-Crawler', function (msg)
  ACL.utils.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Add-Crawler' })
  assert(type(msg.Tags['Crawler-Id']) == 'string', 'Crawler-Id is required')
  local existingCrawler = utils.find(
    function(crawler)
      return crawler.CrawlerId == msg.Tags['Crawler-Id']
    end,
    WuzzyNest.State.Crawlers
  )
  assert(not existingCrawler, 'Crawler-Id already exists')

  local crawlerName = msg.Tags['Crawler-Name'] or 'My Wuzzy Crawler'
  table.insert(WuzzyNest.State.Crawlers, {
    CrawlerId = msg.Tags['Crawler-Id'],
    Creator = msg.From,
    Owner = msg.From,
    Name = crawlerName
  })
  ACL.utils.updateRoles({
    Grant = { [msg.Tags['Crawler-Id']] = { 'Index-Document', 'Report-Crawl-Failure' } }
  })

  ao.send({
    Target = msg.From,
    Action = 'Crawler-Added',
    Data = 'OK',
    ['Crawler-Id'] = msg.Tags['Crawler-Id']
  })
end)

Handlers.add('Remove-Crawler', 'Remove-Crawler', function (msg)
  ACL.utils.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Remove-Crawler' })
  assert(type(msg.Tags['Crawler-Id']) == 'string', 'Crawler-Id is required')
  local existingCrawlerIndex = nil
  local existingCrawler = nil
  for i, crawler in ipairs(WuzzyNest.State.Crawlers) do
    if crawler.CrawlerId == msg.Tags['Crawler-Id'] then
      existingCrawlerIndex = i
      existingCrawler = crawler
      break
    end
  end
  assert(existingCrawler, 'Crawler-Id does not exist')

  table.remove(WuzzyNest.State.Crawlers, existingCrawlerIndex)
  ACL.utils.updateRoles({
    Revoke = { [msg.Tags['Crawler-Id']] = { 'Index-Document', 'Report-Crawl-Failure' } }
  })

  ao.send({
    Target = msg.From,
    Action = 'Crawler-Removed',
    Data = 'OK',
    ['Crawler-Id'] = msg.Tags['Crawler-Id']
  })
end)

Handlers.add('Queue-Crawl-Request', 'Queue-Crawl-Request', function (msg)
  ACL.utils.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Queue-Crawl-Request' })

  local url = msg.Tags['URL']
  local parsed = parseAndNormalizeUrl(url)
  local normalizedUrl = parsed.normalizedUrl

  -- Check we have crawlers
  assert(#WuzzyNest.State.Crawlers > 0, 'No crawlers registered')

  -- Select crawler: use specified Crawler-Id or round-robin
  local crawler = nil
  local specifiedCrawlerId = msg.Tags['Crawler-Id']
  if specifiedCrawlerId then
    crawler = utils.find(
      function(c) return c.CrawlerId == specifiedCrawlerId end,
      WuzzyNest.State.Crawlers
    )
    assert(crawler, 'Specified Crawler-Id not found: ' .. specifiedCrawlerId)
  else
    -- Round-robin selection
    local crawlerIndex = ((WuzzyNest.State.NextCrawlerIndex - 1) % #WuzzyNest.State.Crawlers) + 1
    crawler = WuzzyNest.State.Crawlers[crawlerIndex]
    WuzzyNest.State.NextCrawlerIndex = crawlerIndex + 1
  end

  -- Track pending request
  WuzzyNest.State.PendingCrawlRequests[normalizedUrl] = {
    RequesterId = msg.From,
    CrawlerId = crawler.CrawlerId,
    RequestedAt = msg.Timestamp or 0
  }

  -- Forward request to crawler
  ao.send({
    Target = crawler.CrawlerId,
    Action = 'Request-Crawl',
    ['URL'] = url,
    ['Request-Id'] = normalizedUrl
  })

  ao.send({
    Target = msg.From,
    Action = 'Queue-Crawl-Request-Result',
    ['URL'] = url,
    ['Normalized-URL'] = normalizedUrl,
    ['Assigned-Crawler'] = crawler.CrawlerId,
    Data = 'OK'
  })
end)

Handlers.add('Report-Crawl-Failure', 'Report-Crawl-Failure', function (msg)
  ACL.utils.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Report-Crawl-Failure' })

  local url = msg.Tags['URL']
  local parsed = parseAndNormalizeUrl(url)
  local normalizedUrl = parsed.normalizedUrl

  local reason = msg.Tags['Reason'] or 'Unknown error'

  -- Look up pending request
  local pendingRequest = WuzzyNest.State.PendingCrawlRequests[normalizedUrl]

  if pendingRequest then
    -- Notify original requester of failure
    ao.send({
      Target = pendingRequest.RequesterId,
      Action = 'Crawl-Failed',
      ['URL'] = url,
      ['Normalized-URL'] = normalizedUrl,
      ['Crawler-Id'] = msg.From,
      ['Reason'] = reason,
      Data = reason
    })
    WuzzyNest.State.PendingCrawlRequests[normalizedUrl] = nil
  end

  ao.send({
    Target = msg.From,
    Action = 'Report-Crawl-Failure-Result',
    ['URL'] = url,
    ['Normalized-URL'] = normalizedUrl,
    Data = 'OK'
  })
end)
