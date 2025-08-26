local WuzzyNest = {
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

    WuzzyCrawlerModuleId = nil,
    CrawlerSpawnRefs = {},
    Crawlers = {},

    CrawlTasks = {}
  },
  ACL = require('..common.acl')
}
WuzzyNest.State.WuzzyCrawlerModuleId = module

function WuzzyNest.init()
  local json = require('json')
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

  require('..common.handlers.acl')(WuzzyNest.ACL)
  require('..common.handlers.state')(WuzzyNest)

  Handlers.add('Index-Document', 'Index-Document', function (msg)
    WuzzyNest.ACL.assertHasOneOfRole(msg.from, { 'owner', 'admin', 'Index-Document' })

    local url = msg['Document-URL']
    assert(url, 'Missing Document-URL')
    local parsedUrl = neturl.parse(url):normalize() -- TODO -> Safely parse url
    local protocol = parsedUrl.scheme
    local domain = parsedUrl.host or parsedUrl.authority
    local path = parsedUrl.path
    if path:sub(-1) == '/' then
      path = path:sub(1, -2)
    end
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
      Title = msg['Document-Title'],
      Description = msg['Document-Description']
    }

    if existingDocumentIndex then
      WuzzyNest.State.Documents[existingDocumentIndex] = doc
    else
      table.insert(WuzzyNest.State.Documents, doc)
    end

    send({
      target = msg.from,
      action = 'Index-Document-Result',
      ['Document-Id'] = documentId,
      data = 'OK'
    })
    send({
      device = 'patch@1.0',
      cache = WuzzyNest.State
    })
  end)

  Handlers.add('Remove-Document', 'Remove-Document', function (msg)
    WuzzyNest.ACL.assertHasOneOfRole(msg.from, { 'owner', 'admin', 'Remove-Document' })

    local documentId = msg['Document-Id']
    assert(documentId, 'Document-Id is required')
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
      ['Document-Id'] = documentId,
      data = 'OK'
    })
    send({
      device = 'patch@1.0',
      cache = WuzzyNest.State
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
    WuzzyNest.ACL.assertHasOneOfRole(msg.from, { 'owner', 'admin', 'Add-Crawl-Tasks' })
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
    send({
      device = 'patch@1.0',
      cache = WuzzyNest.State
    })
  end)

  Handlers.add('Remove-Crawl-Tasks', 'Remove-Crawl-Tasks', function (msg)
    WuzzyNest.ACL.assertHasOneOfRole(
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
    send({
      device = 'patch@1.0',
      cache = WuzzyNest.State
    })
  end)

  Handlers.add('Create-Crawler', 'Create-Crawler', function (msg)
    WuzzyNest.ACL.assertHasOneOfRole(msg.from, { 'owner', 'admin', 'Create-Crawler' })
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
    WuzzyNest.State.CrawlerSpawnRefs[xCreateCrawlerId] = {
      Creator = msg.from,
      CrawlerName = crawlerName
    }
    send({
      target = msg.from,
      action = 'Create-Crawler-Result',
      data = 'OK',
      ['X-Create-Crawler-Id'] = xCreateCrawlerId
    })
    send({
      device = 'patch@1.0',
      cache = WuzzyNest.State
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
      Owner = crawlerRef.Creator
    }
    WuzzyNest.State.CrawlerSpawnRefs[xCreateCrawlerId] = nil
    WuzzyNest.ACL.updateRoles({
      Grant = { [crawlerId] = { 'Index-Document' } }
    })

    send({
      target = crawlerRef.Creator,
      action = 'Crawler-Spawned',
      data = 'OK',
      ['Crawler-Id'] = crawlerId,
      ['X-Create-Crawler-Id'] = xCreateCrawlerId
    })
    send({
      device = 'patch@1.0',
      cache = WuzzyNest.State
    })
  end)

  Handlers.add('Add-Crawler', 'Add-Crawler', function (msg)
    WuzzyNest.ACL.assertHasOneOfRole(msg.from, { 'owner', 'admin', 'Add-Crawler' })
    assert(type(msg['Crawler-Id']) == 'string', 'Crawler-Id is required')
    assert(
      not WuzzyNest.State.Crawlers[msg['Crawler-Id']],
      'Crawler-Id already exists'
    )

    local crawlerName = msg['Crawler-Name'] or 'My Wuzzy Crawler'
    WuzzyNest.State.Crawlers[msg['Crawler-Id']] = {
      Creator = msg.from,
      Owner = msg.from,
      Name = crawlerName
    }
    WuzzyNest.ACL.updateRoles({
      Grant = { [msg['Crawler-Id']] = { 'Index-Document' } }
    })

    send({
      target = msg.from,
      action = 'Crawler-Added',
      data = 'OK',
      ['Crawler-Id'] = msg['Crawler-Id']
    })
    send({
      device = 'patch@1.0',
      cache = WuzzyNest.State
    })
  end)

  Handlers.add('Remove-Crawler', 'Remove-Crawler', function (msg)
    WuzzyNest.ACL.assertHasOneOfRole(msg.from, { 'owner', 'admin', 'Remove-Crawler' })
    assert(type(msg['Crawler-Id']) == 'string', 'Crawler-Id is required')
    assert(
      WuzzyNest.State.Crawlers[msg['Crawler-Id']],
      'Crawler-Id does not exist'
    )
    WuzzyNest.State.Crawlers[msg['Crawler-Id']] = nil
    send({
      target = msg.from,
      action = 'Crawler-Removed',
      data = 'OK',
      ['Crawler-Id'] = msg['Crawler-Id']
    })
    send({
      device = 'patch@1.0',
      cache = WuzzyNest.State
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

  WuzzyNest.State.Initialized = true
  send({ device = 'patch@1.0', cache = WuzzyNest.State })
end

if not WuzzyNest.State.Initialized then
  WuzzyNest.init()
end

return WuzzyNest
