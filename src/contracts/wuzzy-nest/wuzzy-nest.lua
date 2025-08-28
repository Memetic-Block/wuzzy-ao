WuzzyNest = {
  State = {
    --- @type boolean
    Initialized = false,

    --- @type { [number]: {
    ---   SubmittedBy: string,
    ---   TransactionId: string,
    ---   ARNSName: string,
    ---   ARNSSubDomain: string,
    ---   ContentType: string,
    ---   Content: string } }
    Documents = {},
    TotalDocuments = 0,
    TotalTermCount = 0,
    AverageDocumentTermLength = 0,
    CrawlerSpawnRefs = {},
    Crawlers = {},
    CrawlTasks = {}
  }
}

function WuzzyNest.init()
  local json = require('json')
  local SimpleSearch = require('.search.simple')
  local BM25Search = require('.search.bm25')
  local StringUtils = require('..common.strings')
  local utils = require('.utils')
  local neturl = require('..lib.neturl')
  local MimeTypesToExtensions = require(
    '..lib.lua-mimetypes.mime-types-to-extensions'
  )
  local ACL = require('..common.acl')
  require('..common.handlers.acl')(ACL)
  require('..common.handlers.state')(WuzzyNest)

  Handlers.add('Index-Document', 'Index-Document', function (msg)
    ACL.assertHasOneOfRole(msg.from, { 'owner', 'admin', 'Index-Document' })

    local url = msg['document-url']
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

    local lastCrawledAtStr = msg['document-last-crawled-at']
    assert(
      type(lastCrawledAtStr) == 'string',
      'Missing document-last-crawled-at'
    )
    local lastCrawledAt = tonumber(lastCrawledAtStr)
    assert(
      lastCrawledAt,
      'Invalid document-last-crawled-at: ' .. lastCrawledAtStr
    )

    local contentType = msg['document-content-type']
    assert(contentType, 'Missing document-content-type')
    assert(
      type(contentType) == 'string' and
        #contentType > 0 and
        MimeTypesToExtensions[contentType],
      'Invalid document-content-type: ' .. contentType
    )

    local existingDocumentIndex = nil
    local existingDocument = nil
    for i, doc in ipairs(WuzzyNest.State.Documents) do
      if doc.DocumentId == documentId then
        existingDocumentIndex = i
        existingDocument = doc
        break
      end
    end

    -- TODO -> Split content into terms
    assert(msg.data and #msg.data > 0, 'Missing Document Content')
    local termCount = #msg.data
    local oldTermCount = existingDocument and existingDocument.TermCount or 0

    WuzzyNest.State.TotalTermCount =
      WuzzyNest.State.TotalTermCount + termCount - oldTermCount

    if not existingDocument then
      WuzzyNest.State.TotalDocuments = WuzzyNest.State.TotalDocuments + 1
    end

    if (WuzzyNest.State.TotalDocuments > 0) then
      WuzzyNest.State.AverageDocumentTermLength =
        WuzzyNest.State.TotalTermCount / WuzzyNest.State.TotalDocuments
    else
      WuzzyNest.State.AverageDocumentTermLength = 0
    end

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
    assert(type(query) == 'string' and #query > 0, 'Missing Search Query')
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

  Handlers.add('Add-Crawl-Tasks', 'Add-Crawl-Tasks', function (msg)
    ACL.assertHasOneOfRole(msg.from, { 'owner', 'admin', 'Add-Crawl-Tasks' })
    assert(msg.data and #msg.data > 0, 'Missing Crawl Task Data')

    for url in msg.data:gmatch('[^\r\n]+') do
      assert(
        not StringUtils.starts_with(url, 'http://'),
        'The http protocol is not yet supported: ' .. url
      )
      assert(
        not StringUtils.starts_with(url, 'https://'),
        'The https protocol is not yet supported: ' .. url
      )
      assert(
        StringUtils.starts_with(url, 'arns://') or
          StringUtils.starts_with(url, 'ar://'),
        'Invalid Crawl Task Data: ' .. url
      )
      assert(
        not WuzzyNest.State.CrawlTasks[url],
        'Duplicate Crawl Task: ' .. url
      )

      WuzzyNest.State.CrawlTasks[url] = { URL = url }
    end

    send({
      target = msg.from,
      action = 'Add-Crawl-Tasks-Result',
      data = 'OK'
    })
  end)

  Handlers.add('Remove-Crawl-Tasks', 'Remove-Crawl-Tasks', function (msg)
    ACL.assertHasOneOfRole(
      msg.from,
      { 'owner', 'admin', 'Remove-Crawl-Tasks' }
    )
    assert(msg.data and #msg.data > 0, 'Missing Crawl Task Data to remove')

    for url in msg.data:gmatch('[^\r\n]+') do
      assert(WuzzyNest.State.CrawlTasks[url], 'Crawl Task not found: ' .. url)
      WuzzyNest.State.CrawlTasks[url] = nil
    end

    send({
      target = msg.from,
      action = 'Remove-Crawl-Tasks-Result',
      data = 'OK'
    })
  end)

  Handlers.add('Add-Crawler', 'Add-Crawler', function (msg)
    ACL.assertHasOneOfRole(msg.from, { 'owner', 'admin', 'Add-Crawler' })
    assert(type(msg['crawler-id']) == 'string', 'crawler-id is required')
    assert(
      not WuzzyNest.State.Crawlers[msg['crawler-id']],
      'crawler-id already exists'
    )

    local crawlerName = msg['crawler-name'] or 'My Wuzzy Crawler'
    WuzzyNest.State.Crawlers[msg['crawler-id']] = {
      Creator = msg.from,
      Owner = msg.from,
      Name = crawlerName
    }
    ACL.updateRoles({
      Grant = { [msg['crawler-id']] = { 'Index-Document' } }
    })

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
    assert(
      WuzzyNest.State.Crawlers[msg['crawler-id']],
      'crawler-id does not exist'
    )
    WuzzyNest.State.Crawlers[msg['crawler-id']] = nil
    send({
      target = msg.from,
      action = 'Crawler-Removed',
      data = 'OK',
      ['crawler-id'] = msg['crawler-id']
    })
  end)

  Handlers.add('Cron', 'Cron', function (msg)
    ACL.assertHasOneOfRole(msg.from, { 'owner', 'admin', 'Cron' })

    local tasks = utils.keys(WuzzyNest.State.CrawlTasks)
    if #tasks < 1 then
      print('No Crawl Tasks to distribute')
      return
    end

    local crawlers = utils.keys(WuzzyNest.State.Crawlers)
    if #crawlers < 1 then
      print('No Crawlers to distribute Crawl Tasks')
      return
    end
  end)

  WuzzyNest.State.Initialized = true
end

if not WuzzyNest.State.Initialized then
  WuzzyNest.init()
end
