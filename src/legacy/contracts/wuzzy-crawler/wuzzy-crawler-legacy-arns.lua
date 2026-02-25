local WuzzyCrawler = {
  State = {
    --- @type string|nil
    NestId = nil,

    --- @type string|nil
    ArioNetworkProcessId = nil,

    --- @type string|nil
    DataOracleAddress = nil,

    --- @type table<string, { AddedBy: string, URL: string }>
    CrawlTasks = {},

    --- @type table<string, boolean>
    SupportedMimeTypes = {
      ['text/html'] = true,
      ['text/plain'] = true,
      ['application/x.arweave-manifest+json'] = true
    },

    --- @type table<string, { Name: string, SubDomain: string }>
    AntRecordRequests = {},

    --- @type table<string, {
    ---   Name: string,
    ---   SubDomain: string,
    ---   URL: string,
    ---   ContentType: string|nil,
    ---   IsManifestPath: boolean|nil }>
    DataOracleRequests = {},

    --- @type table<string, {
    ---   Name: string|nil,
    ---   URL: string }>
    CrawlQueue = {},

    -- Crawl Memory
    --- @type table<string, string>
    CrawledURLs = {}
  }
}

WuzzyCrawler.State.NestId = WuzzyCrawler.State.NestId or
  ao.env.Process.Tags['Nest-Id']
WuzzyCrawler.State.ArioNetworkProcessId =
  WuzzyCrawler.State.ArioNetworkProcessId or
    ao.env.Process.Tags['Ario-Network-Process-Id']
WuzzyCrawler.State.DataOracleAddress =
  WuzzyCrawler.State.DataOracleAddress or
    ao.env.Process.Tags['Data-Oracle-Address']

function WuzzyCrawler.init()
  local json = require('json')
  local ACL = require('..common.acl')
  local StringUtils = require('..common.strings')
  local TagUtils = require('..common.tag-utils')
  local utils = require('.utils')
  local HtmlParser = require('..common.lua-htmlparser.htmlparser')
  local ExtensionsToMimeTypes = require('..common.extensions-to-mime-types')
  local WuzzyDataOracle = require('..common.wuzzy-data-oracle')
  WuzzyDataOracle.OracleAddress = WuzzyCrawler.State.DataOracleAddress

  require('..common.handlers.acl')(ACL)
  require('..common.handlers.state')(WuzzyCrawler)

  Handlers.add(
    'Request-Crawl',
    Handlers.utils.hasMatchingTag('Action', 'Request-Crawl'),
    function (msg)
      ACL.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Request-Crawl' })

      local url = msg.Tags['URL']
      assert(url ~= nil, 'URL tag is required for Request-Crawl')

      local result, err = WuzzyCrawler.crawl(url)
      assert(not err, err)

      ao.send({
        Target = msg.From,
        Action = 'Request-Crawl-Result',
        Data = result
      })
    end
  )

  Handlers.add(
    'Record-Notice',
    Handlers.utils.hasMatchingTag('Action', 'Record-Notice'),
    function (msg)
      if msg.From == WuzzyCrawler.State.ArioNetworkProcessId then
        local name = msg.Tags['Name']
        if type(name) ~= 'string' or name == '' then return end
        if not WuzzyCrawler.State.CrawlQueue['arns://'..name] then
          ao.log('Ignoring Record-Notice for unknown name' .. name)
          return
        end

        -- TODO -> validate msg.Data as StoredRecord
        -- TODO -> safely decode
        --- @class StoredRecord
        --- @field processId string The process id of the record
        --- @field startTimestamp number The start timestamp of the record
        --- @field type 'lease' | 'permabuy' The type of the record (lease/permabuy)
        --- @field undernameLimit number The undername limit of the record
        --- @field purchasePrice number The purchase price of the record
        --- @field endTimestamp number|nil The end timestamp of the record
        local record = json.decode(msg.Data)
        local subdomain = '@' -- TODO -> Handle subdomains
        WuzzyCrawler.State.AntRecordRequests[record.processId] = {
          Name = name,
          SubDomain = subdomain
        }
        ao.send({
          Target = record.processId,
          Action = 'Record',
          ['Sub-Domain'] = subdomain -- TODO -> Handle subdomains
        })
      elseif WuzzyCrawler.State.AntRecordRequests[msg.From] then
        local request = WuzzyCrawler.State.AntRecordRequests[msg.From]
        local url = 'arns://'..request.Name
        local queueItem = WuzzyCrawler.State.CrawlQueue[url]
        if not queueItem then
          ao.log(
            'Ignoring Record-Notice for unknown crawl queue item'..request.Name
          )
          return
        end

        -- TODO -> validate msg.Data as AntRecord
        -- TODO -> safely decode
        --- @class AntRecord
        --- @field transactionId string The transaction id of the record
        --- @field ttlSeconds number The time-to-live seconds of the record
        --- @field priority integer|nil The sort order of the record - must be nil or 1 or greater
        local record = json.decode(msg.Data)

        -- TODO -> Skip default ANT Landing Pages?
        -- oork_YifB3-JQQZg8EgMPQJytua_QCHKNmMqt5kmnCo
        -- -k7t8xMoB8hW482609Z9F4bTFMC3MnuW8bTvTyT8pFI

        WuzzyCrawler.requestTransaction({
          transactionId = record.transactionId,
          url = queueItem.URL,
          name = request.Name,
          subDomain = request.SubDomain,
          protocol = 'arns',
          timestamp = msg.Timestamp
        })

        WuzzyCrawler.State.AntRecordRequests[msg.From] = nil
      end
    end
  )

  Handlers.add(
    'Get-Transaction-Result',
    Handlers.utils.hasMatchingTag('Action', 'Get-Transaction-Result'),
    function (msg)
      local txId = msg.Tags['Transaction-Id']
      local request = WuzzyCrawler.State.DataOracleRequests[
        'Get-Transaction-'..txId
      ]
      if not request then return end

      -- TODO -> handle error results from oracle

      --- @class TransactionHeaders
      --- @field tags { [number]: { name: string, value: string } }
      --- @field id string The transaction id
      --- @field owner string The owner pubkey of the transaction
      --- @field ownerAddress string The owner address of the transaction
      --- @field signature string The signature of the transaction
      --- @field format number The format of the transaction
      --- @field target string The target of the transaction
      --- @field quantity string The quantity of the transaction
      --- @field data_root string The data root of the transaction
      --- @field last_tx string The last transaction id anchor
      --- @field data_size string The data size of the transaction
      --- @field reward string The reward of the transaction
      local tx = json.decode(msg.Data)
      -- TODO -> wrap json decode in pcall
      -- TODO -> validate tx as TransactionHeaders

      local contentType = TagUtils.find(tx.tags, 'Content-Type')
      if not contentType then
        contentType = 'unknown'
      end

      -- TODO -> Don't fetch data if too large
      -- TODO -> Don't fetch data if contentType is unsupported

      WuzzyDataOracle.getData(WuzzyCrawler.State.DataOracleAddress, txId)
      WuzzyCrawler.State.DataOracleRequests['Get-Data-'..txId] = {
        Name = request.Name,
        SubDomain = request.SubDomain,
        ContentType = contentType,
        URL = request.URL,
        IsManifestPath = request.IsManifestPath
      }
      WuzzyCrawler.State.DataOracleRequests['Get-Transaction-'..txId] = nil
    end
  )

  Handlers.add(
    'Get-Data-Result',
    Handlers.utils.hasMatchingTag('Action', 'Get-Data-Result'),
    function (msg)
      local txId = msg.Tags['Transaction-Id']
      local request = WuzzyCrawler.State.DataOracleRequests['Get-Data-'..txId]
      if not request then return end

      -- TODO -> handle error results from oracle
      -- if getDataErr then
      --   return nil, 'Unable to fetch transaction data: ' .. getDataErr
      -- end

      if not msg.Data or msg.Data == '' then
        -- TODO -> crawl result error
        ao.log('Skipping empty data result')
        return
      end

      local result = nil
      local message = nil
      if
        request.ContentType == 'application/x.arweave-manifest+json' and
          request.IsManifestPath
      then
        ao.log('Not parsing arweave manifest: '..json.encode(request))
        return
      elseif request.ContentType == 'application/x.arweave-manifest+json' then
        -- TODO -> Look for robots.txt in the manifest paths
        -- TODO -> Look for sitemap.xml in the manifest paths
        -- TODO -> Don't parse as manifest if it's not a root ARNS URL
        -- TODO -> Validate dataMsg.Data as Arweave manifest
        -- TODO -> Safely decode JSON

        --- @class ArweaveManifest
        --- @field manifest 'arweave/paths' The manifest type
        --- @field version string The manifest version
        --- @field index { path: string } The index file of the manifest
        --- @field fallback? { id: string } The fallback file of the manifest
        --- @field paths { [string]: { id: string } } The paths of the manifest
        local manifest = json.decode(msg.Data)

        for path, info in pairs(manifest.paths) do
          --- NB: Try to skip paths with extensions that we don't support
          local skip = false
          local extension = path:match(".+%.([%a%d]+)$")
          if extension then
            local mimeType = ExtensionsToMimeTypes[extension]
            if mimeType then
              if not WuzzyCrawler.State.SupportedMimeTypes[mimeType] then
                skip = true
              end
            end
          end

          if not skip then
            WuzzyCrawler.requestTransaction({
              transactionId = info.id,
              url = request.URL .. '/' .. path,
              isManifestPath = true
            })
          end
        end

        return
      elseif request.ContentType == 'text/html' then
        result = WuzzyCrawler.parseHTML(msg.Data)
        message = 'HTML content received'
      elseif request.ContentType == 'text/plain' then
        -- TODO -> Parse text content
        result = msg.Data
        message = 'Plain text content received'
      else
        ao.log('Unsupported content type: ' .. request.ContentType)
        -- TODO -> Handle bad crawls
        -- ao.send({
        --   Target = request.requestor,
        --   Action = 'Crawl-Response',
        --   Data = 'Crawl request failed: Unsupported content type:' ..
        --     (request.ContentType or 'unknown')
        -- })
        return
      end

      WuzzyCrawler.submitDocument({
        Id = txId,
        Content = result,
        LastCrawledAt = msg.Timestamp,
        Protocol = 'arns',
        URL = request.URL,
        ContentType = request.ContentType
      })
    end
  )

  Handlers.add(
    'Add-Crawl-Tasks',
    Handlers.utils.hasMatchingTag('Action', 'Add-Crawl-Tasks'),
    function (msg)
      ACL.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Add-Crawl-Tasks' })
      assert(msg.Data and #msg.Data > 0, 'Missing Crawl Task Data')

      for url in msg.Data:gmatch('[^\r\n]+') do
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
          not WuzzyCrawler.State.CrawlTasks[url],
          'Duplicate Crawl Task: ' .. url
        )

        WuzzyCrawler.State.CrawlTasks[url] = {
          AddedBy = msg.From,
          URL = url
        }
      end

      ao.send({
        Target = msg.From,
        Action = 'Add-Crawl-Tasks-Result',
        Data = 'OK'
      })
    end
  )

  Handlers.add(
    'Remove-Crawl-Tasks',
    Handlers.utils.hasMatchingTag('Action', 'Remove-Crawl-Tasks'),
    function (msg)
      ACL.assertHasOneOfRole(
        msg.From,
        { 'owner', 'admin', 'Remove-Crawl-Tasks' }
      )
      assert(msg.Data and #msg.Data > 0, 'Missing Crawl Task Data to remove')

      for url in msg.Data:gmatch('[^\r\n]+') do
        assert(
          WuzzyCrawler.State.CrawlTasks[url],
          'Crawl Task not found: ' .. url
        )
        WuzzyCrawler.State.CrawlTasks[url] = nil
      end

      ao.send({
        Target = msg.From,
        Action = 'Remove-Crawl-Tasks-Result',
        Data = 'OK'
      })
    end
  )

  Handlers.add(
    'Cron',
    Handlers.utils.hasMatchingTag('Action', 'Cron'),
    function (msg)
      assert(msg.From == ao.authorities[1], 'Unauthorized Cron Caller')

      local tasks = utils.keys(WuzzyCrawler.State.CrawlTasks)
      if #tasks < 1 then
        ao.log('No Crawl Tasks to process')
        return
      end

      ao.log('Processing Crawl Tasks: ' .. #tasks)

      for _, task in pairs(WuzzyCrawler.State.CrawlTasks) do
        local err = WuzzyCrawler.crawl(task.URL)
        if err then ao.log(err) end
      end
    end
  )

  function WuzzyCrawler.crawl(url)
    if StringUtils.starts_with(url, 'arns://') then
      -- TODO -> Handle undernames
      local name = string.gsub(url, 'arns://', '')
      WuzzyCrawler.State.CrawlQueue[url] = {
        URL = url,
        Name = name
      }
      ao.send({
        Target = WuzzyCrawler.State.ArioNetworkProcessId,
        Action = 'Record',
        Name = name
      })

      return 'Record request sent to ARNS registry: ' .. name
    else
      return nil, 'Unsupported Crawl Task Protocol: ' .. url
    end
  end

  function WuzzyCrawler.submitDocument(document)
    ao.send({
      Target = WuzzyCrawler.State.NestId,
      Action = 'Index-Document',
      Data = document.Content,
      Tags = {
        ['Document-Id'] = document.Id,
        ['Document-Last-Crawled-At'] = document.LastCrawledAt,
        ['Document-Protocol'] = document.Protocol,
        ['Document-URL'] = document.URL,
        ['Document-Content-Type'] = document.ContentType
      }
    })
  end

  function WuzzyCrawler.parseHTML(html)
    -- TODO -> Safely call stuff below

    local root = HtmlParser.parse(html)
    local body = root:select('body')[1]

    if not body then
      ao.log('No body element found in HTML')
      return ''
    end

    -- Get all text content from body, including child elements
    local content = body:getcontent() or ''

    -- Strip all HTML tags to get just the text content
    content = content:gsub('<[^>]*>', '') -- Remove all HTML tags

    -- Decode HTML entities to their text content
    content = content:gsub('&amp;', '&')  -- Must be first to avoid double-decoding
    content = content:gsub('&lt;', '<')
    content = content:gsub('&gt;', '>')
    content = content:gsub('&quot;', '"')
    content = content:gsub('&#39;', "'")
    content = content:gsub('&#x27;', "'")
    content = content:gsub('&apos;', "'")
    content = content:gsub('&nbsp;', ' ')
    content = content:gsub('&copy;', '©')
    content = content:gsub('&reg;', '®')
    content = content:gsub('&trade;', '™')
    content = content:gsub('&hellip;', '…')
    content = content:gsub('&mdash;', '—')
    content = content:gsub('&ndash;', '–')
    content = content:gsub('&ldquo;', '"')
    content = content:gsub('&rdquo;', '"')
    content = content:gsub('&lsquo;', "'")
    content = content:gsub('&rsquo;', "'")

    -- Decode numeric character references (decimal)
    content = content:gsub('&#(%d+);', function(n)
      local num = tonumber(n)
      if num and num >= 32 and num <= 126 then
        return string.char(num)
      end
      return ''
    end)

    -- Clean up extra whitespace and newlines
    content = content:gsub('%s+', ' ') -- Replace multiple whitespace with single space
    content = content:gsub('^%s+', '') -- Trim leading whitespace
    content = content:gsub('%s+$', '') -- Trim trailing whitespace

    return content
  end

  function WuzzyCrawler.requestTransaction(opts)
    if WuzzyCrawler.State.CrawledURLs[opts.url] == opts.transactionId then
      WuzzyCrawler.submitDocument({
        Id = opts.transactionId,
        LastCrawledAt = opts.timestamp,
        Protocol = 'arns',
        URL = opts.url
      })
    else
      WuzzyDataOracle.getTx(
        WuzzyCrawler.State.DataOracleAddress,
        opts.transactionId
      )
      WuzzyCrawler.State.DataOracleRequests[
        'Get-Transaction-' .. opts.transactionId
      ] = {
        URL = opts.url,
        Name = opts.name,
        SubDomain = opts.subDomain,
        IsManifestPath = opts.isManifestPath
      }
      WuzzyCrawler.State.CrawledURLs[opts.url] = opts.transactionId
    end
  end
end

WuzzyCrawler.init()
