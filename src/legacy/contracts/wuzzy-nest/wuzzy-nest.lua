WuzzyNest = {
  Version = '0.0.1-hackathon',
  State = {
    --- @type boolean
    Initialized = false,

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
    Crawlers = {}
  }
}

function WuzzyNest.init()
  local json = require('json')
  local SimpleSearch = require('.search.simple')
  local BM25Search = require('.search.bm25')
  local utils = require('.utils')
  local neturl = require('..lib.neturl')
  local ACL = require('..common.acl')
  require('..common.handlers.acl')(ACL)

  Handlers.add('Index-Document', 'Index-Document', function (msg)
    ACL.assertHasOneOfRole(msg.from, { 'owner', 'admin', 'Index-Document' })

    local url = msg['document-url']
    print('got document-url', url)
    assert(url, 'Missing document-url')
    local parsedUrl = neturl.parse(url):normalize() -- TODO -> Safely parse url
    local protocol = parsedUrl.scheme
    local domain = parsedUrl.host or parsedUrl.authority
    local path = parsedUrl.path
    if path:sub(-1) == '/' then
      path = path:sub(1, -2)
    end
    assert(protocol and domain and path, 'Invalid document-url: ' .. url)
    local documentId = protocol .. '://' .. domain .. path
    print('got document-id', documentId)

    local lastCrawledAtStr = msg['document-last-crawled-at']
    assert(
      type(lastCrawledAtStr) == 'string',
      'Missing document-last-crawled-at'
    )
    local lastCrawledAt = lastCrawledAtStr
    assert(
      type(lastCrawledAt) == 'string',
      'Invalid document-last-crawled-at: ' .. lastCrawledAtStr
    )
    print('got document-last-crawled-at', lastCrawledAt)

    local contentType = msg['document-content-type']
    assert(contentType, 'Missing document-content-type')
    print('checking content type', tostring(contentType))
    assert(
      type(contentType) == 'string' and contentType ~= '',
      'Invalid document-content-type: ' .. contentType
    )
    print('got document-content-type', contentType)

    local existingDocumentIndex = nil
    local existingDocument = nil
    for i, doc in ipairs(WuzzyNest.State.Documents) do
      if doc.DocumentId == documentId then
        existingDocumentIndex = i
        existingDocument = doc
        break
      end
    end
    print('got existingDocument', existingDocument and 'found' or 'not found')

    assert(msg.data and #msg.data > 0, 'Missing Document Content')
    local termCount = select(2, string.gsub(msg.data, '[^%s%p]+', ''))
    local oldTermCount = existingDocument and existingDocument.TermCount or 0
    print('got term count', termCount)
    WuzzyNest.State.TotalTermCount =
      WuzzyNest.State.TotalTermCount + termCount - oldTermCount
    print('new total term count', WuzzyNest.State.TotalTermCount)

    local oldContentLength = existingDocument and existingDocument.ContentLength or 0
    WuzzyNest.State.TotalContentLength =
      WuzzyNest.State.TotalContentLength + #msg.data - oldContentLength
    print('new total content length', WuzzyNest.State.TotalContentLength)

    if not existingDocument then
      WuzzyNest.State.TotalDocuments = WuzzyNest.State.TotalDocuments + 1
    end
    print('new total documents', WuzzyNest.State.TotalDocuments)

    if (WuzzyNest.State.TotalDocuments > 0) then
      WuzzyNest.State.AverageDocumentTermLength =
        WuzzyNest.State.TotalTermCount / WuzzyNest.State.TotalDocuments
    else
      WuzzyNest.State.AverageDocumentTermLength = 0
    end
    print('new avg doc length', WuzzyNest.State.AverageDocumentTermLength)

    local doc = {
      SubmittedBy = msg.from,
      DocumentId = documentId,
      LastCrawledAt = lastCrawledAt,
      Protocol = protocol,
      Domain = domain,
      Path = path,
      URL = url,
      ContentType = contentType,
      Content = msg.data,
      ContentLength = #msg.data,
      TermCount = termCount,
      Title = msg['document-title'],
      Description = msg['document-description']
    }

    if existingDocumentIndex then
      WuzzyNest.State.Documents[existingDocumentIndex] = doc
    else
      table.insert(WuzzyNest.State.Documents, doc)
    end

    send({
      target = msg.from,
      action = 'Index-Document-Result',
      ['document-id'] = documentId,
      data = 'OK'
    })
  end)

  Handlers.add('Remove-Document', 'Remove-Document', function (msg)
    ACL.assertHasOneOfRole(msg.from, { 'owner', 'admin', 'Remove-Document' })

    local documentId = msg['document-id']
    assert(documentId, 'document-id is required')
    local document = utils.find(
      function(doc) return doc.DocumentId == documentId end,
      WuzzyNest.State.Documents
    )
    assert(document, 'Document not found')

    for i, doc in ipairs(WuzzyNest.State.Documents) do
      if doc.DocumentId == documentId then
        table.remove(WuzzyNest.State.Documents, i)
        break
      end
    end

    WuzzyNest.State.TotalDocuments = WuzzyNest.State.TotalDocuments - 1

    send({
      target = msg.from,
      action = 'Remove-Document-Result',
      ['document-id'] = documentId,
      data = 'OK'
    })
  end)

  Handlers.add('Search', 'Search', function (msg)
    local query = msg['query']
    assert(type(query) == 'string' and query ~= '', 'Missing Search Query')
    local searchType = msg['search-type'] or 'simple'
    local hits = {}
    if searchType == 'simple' then
      hits = SimpleSearch.search(query, WuzzyNest.State)
    elseif searchType == 'bm25' then
      hits = BM25Search.search(query, WuzzyNest.State)
    end

    send({
      target = msg.from,
      action = 'Search-Result',
      data = json.encode({
        SearchType = searchType,
        Hits = hits,
        TotalCount = #hits
      })
    })
  end)

  Handlers.add('Add-Crawler', 'Add-Crawler', function (msg)
    ACL.assertHasOneOfRole(msg.from, { 'owner', 'admin', 'Add-Crawler' })
    assert(type(msg['crawler-id']) == 'string', 'crawler-id is required')
    local existingCrawler = utils.find(
      function(crawler)
        return crawler.CrawlerId == msg['crawler-id']
      end,
      WuzzyNest.State.Crawlers
    )
    assert(not existingCrawler, 'crawler-id already exists')

    local crawlerName = msg['crawler-name'] or 'My Wuzzy Crawler'
    table.insert(WuzzyNest.State.Crawlers, {
      CrawlerId = msg['crawler-id'],
      Creator = msg.from,
      Owner = msg.from,
      Name = crawlerName
    })
    ACL.updateRoles({ Grant = { [msg['crawler-id']] = { 'Index-Document' } } })

    send({
      target = msg.from,
      action = 'Crawler-Added',
      data = 'OK',
      ['crawler-id'] = msg['crawler-id']
    })
  end)

  Handlers.add('Remove-Crawler', 'Remove-Crawler', function (msg)
    ACL.assertHasOneOfRole(msg.from, { 'owner', 'admin', 'Remove-Crawler' })
    assert(type(msg['crawler-id']) == 'string', 'crawler-id is required')
    local existingCrawlerIndex = nil
    local existingCrawler = nil
    for i, crawler in ipairs(WuzzyNest.State.Crawlers) do
      if crawler.CrawlerId == msg['crawler-id'] then
        existingCrawlerIndex = i
        existingCrawler = crawler
        break
      end
    end
    assert(existingCrawler, 'crawler-id does not exist')

    table.remove(WuzzyNest.State.Crawlers, existingCrawlerIndex)
    ACL.updateRoles({ Revoke = { [msg['crawler-id']] = { 'Index-Document' } } })
    send({
      target = msg.from,
      action = 'Crawler-Removed',
      data = 'OK',
      ['crawler-id'] = msg['crawler-id']
    })
  end)

  WuzzyNest.State.Initialized = true
end

if not WuzzyNest.State.Initialized then
  WuzzyNest.init()
end
