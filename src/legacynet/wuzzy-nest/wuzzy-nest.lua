-- Wuzzy Nest for AO Legacynet
-- Ported from hyperbeam version with legacynet conventions:
-- - Uses msg.From, msg.Data, msg.Tags['Tag-Name'] instead of msg.from, msg.data, msg['tag-name']
-- - Uses Handlers.utils.hasMatchingTag('Action', 'Action-Name') pattern
-- - Uses ao.send({Target, Action, Data}) instead of send({target, action, data})
-- - Search is stubbed to return all documents (no ranking)

WuzzyNest = {
  Version = '0.0.1-legacynet',
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
  local utils = require('.common.utils')
  local neturl = require('.lib.neturl')
  local ACL = require('.common.acl')
  require('.common.handlers.acl')(ACL)

  Handlers.add(
    'Index-Document',
    Handlers.utils.hasMatchingTag('Action', 'Index-Document'),
    function (msg)
      ACL.utils.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Index-Document' })

      local url = msg.Tags['Document-URL']
      print('got document-url', url)
      assert(url, 'Missing Document-URL')
      local parsedUrl = neturl.parse(url):normalize()
      local protocol = parsedUrl.scheme
      local domain = parsedUrl.host or parsedUrl.authority
      local path = parsedUrl.path
      if path:sub(-1) == '/' then
        path = path:sub(1, -2)
      end
      assert(protocol and domain and path, 'Invalid Document-URL: ' .. url)
      local documentId = protocol .. '://' .. domain .. path
      print('got document-id', documentId)

      local lastCrawledAtStr = msg.Tags['Document-Last-Crawled-At']
      assert(
        type(lastCrawledAtStr) == 'string',
        'Missing Document-Last-Crawled-At'
      )
      local lastCrawledAt = lastCrawledAtStr
      assert(
        type(lastCrawledAt) == 'string',
        'Invalid Document-Last-Crawled-At: ' .. lastCrawledAtStr
      )
      print('got document-last-crawled-at', lastCrawledAt)

      local contentType = msg.Tags['Document-Content-Type']
      assert(contentType, 'Missing Document-Content-Type')
      print('checking content type', tostring(contentType))
      assert(
        type(contentType) == 'string' and contentType ~= '',
        'Invalid Document-Content-Type: ' .. contentType
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

      assert(msg.Data and #msg.Data > 0, 'Missing Document Content')
      local termCount = select(2, string.gsub(msg.Data, '[^%s%p]+', ''))
      local oldTermCount = existingDocument and existingDocument.TermCount or 0
      print('got term count', termCount)
      WuzzyNest.State.TotalTermCount =
        WuzzyNest.State.TotalTermCount + termCount - oldTermCount
      print('new total term count', WuzzyNest.State.TotalTermCount)

      local oldContentLength = existingDocument and existingDocument.ContentLength or 0
      WuzzyNest.State.TotalContentLength =
        WuzzyNest.State.TotalContentLength + #msg.Data - oldContentLength
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
        WuzzyNest.State.Documents[existingDocumentIndex] = doc
      else
        table.insert(WuzzyNest.State.Documents, doc)
      end

      ao.send({
        Target = msg.From,
        Action = 'Index-Document-Result',
        ['Document-Id'] = documentId,
        Data = 'OK'
      })
    end
  )

  Handlers.add(
    'Remove-Document',
    Handlers.utils.hasMatchingTag('Action', 'Remove-Document'),
    function (msg)
      ACL.utils.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Remove-Document' })

      local documentId = msg.Tags['Document-Id']
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

      ao.send({
        Target = msg.From,
        Action = 'Remove-Document-Result',
        ['Document-Id'] = documentId,
        Data = 'OK'
      })
    end
  )

  -- Search handler - STUB: returns all documents (no ranking/filtering)
  -- TODO: Port search modules (simple, bm25) for full search functionality
  Handlers.add(
    'Search',
    Handlers.utils.hasMatchingTag('Action', 'Search'),
    function (msg)
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
    end
  )

  Handlers.add(
    'Add-Crawler',
    Handlers.utils.hasMatchingTag('Action', 'Add-Crawler'),
    function (msg)
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
      ACL.utils.updateRoles({ Grant = { [msg.Tags['Crawler-Id']] = { 'Index-Document' } } })

      ao.send({
        Target = msg.From,
        Action = 'Crawler-Added',
        Data = 'OK',
        ['Crawler-Id'] = msg.Tags['Crawler-Id']
      })
    end
  )

  Handlers.add(
    'Remove-Crawler',
    Handlers.utils.hasMatchingTag('Action', 'Remove-Crawler'),
    function (msg)
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
      ACL.utils.updateRoles({ Revoke = { [msg.Tags['Crawler-Id']] = { 'Index-Document' } } })
      ao.send({
        Target = msg.From,
        Action = 'Crawler-Removed',
        Data = 'OK',
        ['Crawler-Id'] = msg.Tags['Crawler-Id']
      })
    end
  )

  WuzzyNest.State.Initialized = true
end

if not WuzzyNest.State.Initialized then
  WuzzyNest.init()
end
