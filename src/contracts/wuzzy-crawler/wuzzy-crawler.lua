local WuzzyCrawler = {
  State = {
    --- @type string|nil
    NestId = nil,

    --- @type string|nil
    Gateway = nil,

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
  process.Tags['Nest-Id']
WuzzyCrawler.State.Gateway = WuzzyCrawler.State.Gateway or
  process.Tags['Gateway'] or 'arweave.net'

function WuzzyCrawler.init()
  local ACL = require('..common.acl')
  local utils = require('.utils')
  local StringUtils = require('..common.strings')
  local HtmlParser = require('..common.lua-htmlparser.htmlparser')
  local neturl = require('..lib.neturl')

  require('..common.handlers.acl')(ACL)
  require('..common.handlers.state')(WuzzyCrawler)

  Handlers.add('Request-Crawl', 'Request-Crawl', function (msg)
    ACL.assertHasOneOfRole(msg.from, { 'owner', 'admin', 'Request-Crawl' })

    local url = msg['URL']
    assert(url ~= nil, 'Missing URL to crawl')

    local result, err = WuzzyCrawler.enqueueCrawl(url)
    assert(not err, err)

    send({
      target = msg.from,
      action = 'Request-Crawl-Result',
      data = result
    })
  end)

  Handlers.add('Add-Crawl-Tasks', 'Add-Crawl-Tasks', function (msg)
    ACL.assertHasOneOfRole(msg.from, { 'owner', 'admin', 'Add-Crawl-Tasks' })
    assert(msg.data and #msg.data > 0, 'Missing Crawl Task Data')

    for url in msg.data:gmatch('[^\r\n]+') do
      -- TODO -> validate url
      -- TODO -> Safely parse url
      local parsedUrl = neturl.parse(url)
      local protocol = parsedUrl.scheme
      local domain = parsedUrl.host or parsedUrl.authority
      local path = parsedUrl.path
      assert(protocol and domain and path, 'Invalid Crawl Task Data: ' .. url)
      local baseUrl = protocol .. '://' .. domain .. path
      assert(
        not WuzzyCrawler.State.CrawlTasks[baseUrl],
        'Duplicate Crawl Task: ' .. baseUrl
      )
      WuzzyCrawler.State.CrawlTasks[baseUrl] = {
        AddedBy = msg.from,
        SubmittedUrl = url,
        URL = baseUrl,
        Protocol = protocol,
        Domain = domain,
        Path = path
      }
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
      assert(
        WuzzyCrawler.State.CrawlTasks[url],
        'Crawl Task not found: ' .. url
      )
      WuzzyCrawler.State.CrawlTasks[url] = nil
    end

    send({
      target = msg.from,
      action = 'Remove-Crawl-Tasks-Result',
      data = 'OK'
    })
  end)

  Handlers.add('Cron', 'Cron', function (msg)
    assert(msg.from == authorities[1], 'Unauthorized Cron Caller')

    local queue = utils.keys(WuzzyCrawler.State.CrawlQueue)
    if #queue < 1 then
      print('Nothing in Crawl Queue')

      local tasks = utils.keys(WuzzyCrawler.State.CrawlTasks)
      if #tasks < 1 then
        print('No Crawl Tasks to process')
        return
      end

      print('Processing Crawl Tasks: ' .. #tasks)
      for _, task in pairs(WuzzyCrawler.State.CrawlTasks) do
        local result, err = WuzzyCrawler.enqueueCrawl(task.URL)
        if err then print('Enqueue Crawl Error:', err) end
        if result then print('Enqueue Crawl Result:', result) end
      end
    end

    queue = utils.keys(WuzzyCrawler.State.CrawlQueue)
    if queue[1] then
      local result, err = WuzzyCrawler.dequeueCrawl(queue[1])
      if err then print('Dequeue Crawl Error:', err) end
      if result then print('Dequeue Crawl Result:', result) end
    end
  end)

  Handlers.add('Relay-Result', 'Relay-Result', function (msg)
    assert(msg.from == id, 'Unauthorized Relay-Result Caller')

    if msg['content-type'] == 'text/html' then
      local parsed = WuzzyCrawler.parseHTML(msg.body)
      local links = utils.map(
        function (link)
          if StringUtils.starts_with(link, '/') then
            local parsedUrl = neturl.parse(msg['relay-path'])
            local protocol = parsedUrl.scheme
            local domain = parsedUrl.host or parsedUrl.authority
            return protocol .. '://' .. domain .. link
          end

          return link
        end,
        parsed.links
      )

      WuzzyCrawler.submitDocument({
        Id = msg['relay-path'],
        URL = msg['relay-path'],
        ContentType = msg['content-type'],
        LastCrawledAt = msg['block-timestamp'],
        Content = parsed.content
      })
      for _, url in ipairs(links) do
        print('Discovered link:', url)
        local result, err = WuzzyCrawler.enqueueCrawl(url)
        if err then print('Enqueue Crawl Error:', err) end
        if result then print('Enqueue Crawl Result:', result) end
      end
    elseif msg['content-type'] == 'text/plain' then
      WuzzyCrawler.submitDocument({
        Id = msg['relay-path'],
        URL = msg['relay-path'],
        ContentType = msg['content-type'],
        LastCrawledAt = msg['block-timestamp'],
        Content = msg.body
      })
    else
      print(
        'Ignoring url: ' .. tostring(msg['relay-path']) ..
        ' with content-type: ' .. tostring(msg['content-type'])
      )
    end
  end)

  function WuzzyCrawler.dequeueCrawl(url)
    local relayPath = url

    if StringUtils.starts_with(url, 'arns://') then
      local parsed = neturl.parse(url)
      local domain = parsed.host or parsed.authority
      local path = parsed.path
      relayPath = 'https://' .. domain .. '.' .. WuzzyCrawler.State.Gateway
      if path and path ~= '' then
        relayPath = relayPath .. path
      end
    elseif StringUtils.starts_with(url, 'ar://') then
      local parsed = neturl.parse(url)
      local txid = parsed.host or parsed.authority
      local path = parsed.path
      relayPath = 'https://' .. WuzzyCrawler.State.Gateway .. '/' .. txid
      if path and path ~= '' then
        relayPath = relayPath .. path
      end
    end

    send({
      target = id,
      ['relay-path'] = relayPath,
      resolve = '~relay@1.0/call/~patch@1.0',
      action = 'Relay-Result'
    })
    WuzzyCrawler.State.CrawlQueue[url] = nil
    return 'Crawled ' .. url
  end

  function WuzzyCrawler.enqueueCrawl(url)
    -- TODO -> validate url
    -- TODO -> Safely parse url
    local parsedUrl = neturl.parse(url)
    local protocol = parsedUrl.scheme
    local domain = parsedUrl.host or parsedUrl.authority
    local path = parsedUrl.path

    if protocol and domain and path then
      if utils.includes(protocol, { 'http', 'https', 'arns', 'ar' }) then
        local baseUrl = protocol .. '://' .. domain .. path
        WuzzyCrawler.State.CrawlQueue[baseUrl] = {
          SubmittedUrl = url,
          URL = baseUrl,
          Protocol = protocol,
          Domain = domain,
          Path = path
        }

        return 'URL added to crawl queue: ' .. baseUrl
      else
        return nil, 'Unsupported Crawl Task Protocol: ' .. url
      end
    else
      return nil, 'Invalid URL: ' .. url
    end
  end

  function WuzzyCrawler.submitDocument(document)
    send({
      target = WuzzyCrawler.State.NestId,
      action = 'Index-Document',
      data = document.Content,
      ['Document-Id'] = document.Id,
      ['Document-Last-Crawled-At'] = document.LastCrawledAt,
      ['Document-URL'] = document.URL,
      ['Document-Content-Type'] = document.ContentType
    })
  end

  function WuzzyCrawler.parseHTML(html)
    -- TODO -> Safely call stuff below

    local root = HtmlParser.parse(html, 10000)
    local titleElement = root:select('title')[1]
    local title = titleElement and titleElement:getcontent() or ''
    local descElement = root:select('meta[name="description"]')[1]
    local description =
      descElement and descElement.attributes['content'] or ''
    local anchorElements = root:select('a')
    local links = {}
    for _, anchor in ipairs(anchorElements) do
      local href = anchor.attributes['href']
      if
        href and
        href ~= '' and
        href ~= '/index.html' and
        (not StringUtils.starts_with(href, '#')) and
        (not StringUtils.starts_with(href, '/#')) and
        (not utils.find(function(link) return link == href end, links))
      then
        table.insert(links, href)
      end
    end
    local body = root:select('body')[1]

    if not body then
      print('No body element found in HTML')
      return ''
    end

    -- Get all text content from body, including child elements
    local content = body:getcontent() or ''

    -- Strip all HTML tags to get just the text content
    content = content:gsub('<[^>]*>', ' ') -- Remove all HTML tags

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

    return {
      title = title,
      description = description,
      links = links,
      content = content
    }
  end
end

WuzzyCrawler.init()

return WuzzyCrawler
