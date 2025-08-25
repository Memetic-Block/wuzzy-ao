local WuzzyNest = {
  State = {
    IndexType = 'ARNS',

    --- @type { [number]: {
    ---   SubmittedBy: string,
    ---   TransactionId: string,
    ---   IndexType: string,
    ---   ARNSName: string,
    ---   ARNSSubDomain: string,
    ---   ContentType: string,
    ---   Content: string } }
    Documents = {},
    TotalDocuments = 0,
    TotalTermCount = 0,
    AverageDocumentTermLength = 0,

    WuzzyCrawlerModuleId = nil,
    CrawlerSpawnRefs = {},
    Crawlers = {},

    CrawlTasks = {}
  }
}

WuzzyNest.State.WuzzyCrawlerModuleId = module

function WuzzyNest.init()
  local json = require('json')
  local ACL = require('..common.acl')
  local SimpleSearch = require('.search.simple')
  local BM25Search = require('.search.bm25')
  local StringUtils = require('..common.strings')
  local utils = require('.utils')
  local base64 = require('.base64')
  local neturl = require('..lib.neturl')
  local MimeTypesToExtensions = require('..lib.lua-mimetypes.mime-types-to-extensions')
  local WuzzyCrawlerCode = base64.decode(
    require('..wuzzy-crawler.wuzzy-crawler-stringified')
  )

  require('..common.handlers.acl')(ACL)
  require('..common.handlers.state')(WuzzyNest)

  Handlers.add('Index-Document', 'Index-Document', function (msg)
    ACL.assertHasOneOfRole(msg.from, { 'owner', 'admin', 'Index-Document' })

    local url = msg['Document-URL']
    assert(url, 'Missing Document-URL')
    local parsedUrl = neturl.parse(url) -- TODO -> Safely parse url
    local protocol = parsedUrl.scheme
    local domain = parsedUrl.host or parsedUrl.authority
    local path = parsedUrl.path
    assert(protocol and domain and path, 'Invalid Document-URL: ' .. url)
    local documentId = protocol .. '://' .. domain .. path

    local lastCrawledAtStr = msg['Document-Last-Crawled-At']
    assert(
      type(lastCrawledAtStr) == 'string',
      'Missing Document-Last-Crawled-At'
    )
    local lastCrawledAt = tonumber(lastCrawledAtStr)
    assert(
      lastCrawledAt,
      'Invalid Document-Last-Crawled-At: ' .. lastCrawledAtStr
    )

    local contentType = msg['Document-Content-Type']
    assert(contentType, 'Missing Document-Content-Type')
    assert(
      type(contentType) == 'string' and
        #contentType > 0 and
        MimeTypesToExtensions[contentType],
      'Invalid Document-Content-Type: ' .. contentType
    )

    local alreadyExists = not not WuzzyNest.State.Documents[documentId]
    if not alreadyExists then
      assert(msg.data and #msg.data > 0, 'Missing Document Content')
    end

    -- TODO -> Split content into terms

    local termCount = #msg.data
    local oldTermCount = alreadyExists and WuzzyNest.State.Documents[documentId].TermCount or 0

    WuzzyNest.State.TotalTermCount =
      WuzzyNest.State.TotalTermCount + termCount - oldTermCount

    if not alreadyExists then
      WuzzyNest.State.TotalDocuments = WuzzyNest.State.TotalDocuments + 1
    end

    if (WuzzyNest.State.TotalDocuments > 0) then
      WuzzyNest.State.AverageDocumentTermLength =
        WuzzyNest.State.TotalTermCount / WuzzyNest.State.TotalDocuments
    else
      WuzzyNest.State.AverageDocumentTermLength = 0
    end

    WuzzyNest.State.Documents[documentId] = {
      SubmittedBy = msg.from,
      DocumentId = documentId,
      LastCrawledAt = lastCrawledAt,
      Protocol = protocol,
      Domain = domain,
      Path = path,
      URL = url,
      ContentType = contentType,
      Content = msg.data,
      TermCount = termCount
    }

    send({
      target = msg.from,
      action = 'Index-Document-Result',
      ['Document-Id'] = documentId,
      data = 'OK'
    })
  end)

  Handlers.add('Remove-Document', 'Remove-Document', function (msg)
    ACL.assertHasOneOfRole(msg.from, { 'owner', 'admin', 'Remove-Document' })

    local documentId = msg['Document-Id']
    assert(documentId, 'Document-Id is required')
    local document = WuzzyNest.State.Documents[documentId]
    assert(document, 'Document not found')

    WuzzyNest.State.Documents[documentId] = nil
    WuzzyNest.State.TotalDocuments = WuzzyNest.State.TotalDocuments - 1

    send({
      target = msg.from,
      action = 'Remove-Document-Result',
      ['Document-Id'] = documentId,
      data = 'OK'
    })
  end)

  Handlers.add('Search', 'Search', function (msg)
    local query = msg['Query'] or msg['query']
    assert(type(query) == 'string' and #query > 0, 'Missing Search Query')
    local searchType = msg['Search-Type'] or 'simple'
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

  Handlers.add('Create-Crawler', 'Create-Crawler', function (msg)
    ACL.assertHasOneOfRole(msg.from, { 'owner', 'admin', 'Create-Crawler' })
    local crawlerName = msg['Crawler-Name'] or 'My Wuzzy Crawler'
    local xCreateCrawlerId = msg.id

    spawn(WuzzyNest.State.WuzzyCrawlerModuleId, {
      ['App-Name'] = 'Wuzzy',
      ['Contract-Name'] = 'wuzzy-crawler',
      authority = authorities[1],
      ['X-Create-Crawler-Id'] = xCreateCrawlerId,
      ['Crawler-Name'] = crawlerName,
      ['Crawler-Creator'] = msg.from
    })
    WuzzyNest.State.CrawlerSpawnRefs[msg.id] = {
      Creator = msg.from,
      CrawlerName = crawlerName
    }
    send({
      target = msg.from,
      action = 'Create-Crawler-Result',
      data = 'OK',
      ['X-Create-Crawler-Id'] = xCreateCrawlerId
    })
  end)

  Handlers.add('Spawned', 'Spawned', function (msg)
    if msg.from ~= id then
      print(
        'Ignoring Spawned message from unknown process: ' ..
          tostring(msg.from)
      )
      return
    end

    local fromProcess = msg['From-Process']
    if fromProcess ~= id then
      print(
        'Ignoring Spawned message from unknown process: ' ..
          tostring(fromProcess)
      )
      return
    end

    local xCreateCrawlerId = msg['X-Create-Crawler-Id']
    if not xCreateCrawlerId then
      print('Ignoring Spawned message without X-Create-Crawler-Id tag')
      return
    end

    local crawlerRef = WuzzyNest.State.CrawlerSpawnRefs[xCreateCrawlerId]
    if not crawlerRef then
      print(
        'Ignoring Spawned message with unknown X-Create-Crawler-Id: ' ..
          tostring(xCreateCrawlerId)
      )
      return
    end

    local crawlerId = msg['Process']
    if not crawlerId or type(crawlerId) ~= 'string' then
      print(
        'Ignoring Spawned message without valid Process tag: ' ..
          tostring(crawlerId)
      )
      return
    end

    send({
      target = crawlerId,
      action = 'Eval',
      data = WuzzyCrawlerCode
    })

    WuzzyNest.State.Crawlers[crawlerId] = {
      ['X-Create-Crawler-Id'] = xCreateCrawlerId,
      Name = crawlerRef.CrawlerName,
      Creator = crawlerRef.Creator,
      Owner = crawlerRef.Creator,
      Roles = {}
    }
    WuzzyNest.State.CrawlerSpawnRefs[xCreateCrawlerId] = nil

    send({
      target = crawlerRef.Creator,
      action = 'Crawler-Spawned',
      data = 'OK',
      ['Crawler-Id'] = crawlerId,
      ['X-Create-Crawler-Id'] = xCreateCrawlerId
    })
  end)

  Handlers.add('Cron', 'Cron', function (msg)
    assert(msg.from == ao.authorities[1], 'Unauthorized Cron Caller')

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
end

WuzzyNest.init()

return WuzzyNest
