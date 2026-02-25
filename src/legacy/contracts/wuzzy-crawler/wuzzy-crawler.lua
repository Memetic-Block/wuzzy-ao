WuzzyCrawler = {
  Version = '0.0.1-hackathon',
  State = {
    --- @type boolean
    Initialized = false,

    --- @type string|nil
    NestId = nil,

    --- @type string|nil
    Gateway = nil,

    --- @type table<number, {
    ---   AddedBy: string,
    ---   URL: string,
    ---   SubmittedUrl: string,
    ---   Protocol: string,
    ---   Domain: string,
    ---   Path: string,
    --- }>
    CrawlTasks = {},

    --- @type table<number, {
    ---   SubmittedUrl: string,
    ---   URL: string,
    ---   Protocol: string,
    ---   Domain: string,
    ---   Path: string,
    --- }>
    CrawlQueue = {},

    --- CrawledURLs memory, wiped when the CrawlQueue is drained completely
    --- @type table<number, string>
    CrawledURLs = {}
  }
}

WuzzyCrawler.State.NestId = process['nest-id'] or id
WuzzyCrawler.State.Gateway = process['gateway'] or 'https://arweave.net'

function WuzzyCrawler.init()
  local ACL = require('..common.acl')
  local utils = require('.utils')
  local StringUtils = require('..common.strings')
  local neturl = require('..lib.neturl')
  local HtmlParser = require('..common.lua-htmlparser.htmlparser')
  require('..lib.ao-string-ext')
  require('..common.handlers.acl')(ACL)

  Handlers.add('Request-Crawl', 'Request-Crawl', function (msg)
    ACL.assertHasOneOfRole(msg.from, { 'owner', 'admin', 'Request-Crawl' })

    local url = msg['URL']
    assert(url ~= nil, 'Missing URL to crawl')

    local result, err = EnqueueCrawl(url)
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

    for url in string.gmatch(msg.data, '[^\r\n]+') do
      -- TODO -> validate url
      -- TODO -> Safely parse url
      local parsedUrl = neturl.parse(url)
      local protocol = parsedUrl.scheme
      local domain = parsedUrl.host or parsedUrl.authority
      local path = parsedUrl.path
      assert(protocol and domain and path, 'Invalid Crawl Task Data: ' .. url)
      local baseUrl = protocol .. '://' .. domain .. path

      assert(
        not utils.find(
          function(task) return task.URL == baseUrl end,
          WuzzyCrawler.State.CrawlTasks
        ),
        'Duplicate Crawl Task: ' .. baseUrl
      )
      table.insert(WuzzyCrawler.State.CrawlTasks, {
        AddedBy = msg.from,
        SubmittedUrl = url,
        URL = baseUrl,
        Protocol = protocol,
        Domain = domain,
        Path = path
      })
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

    for url in string.gmatch(msg.data, '[^\r\n]+') do
      local found = false
      for i, task in ipairs(WuzzyCrawler.State.CrawlTasks) do
        if task.URL == url then
          table.remove(WuzzyCrawler.State.CrawlTasks, i)
          found = true
          break
        end
      end
      assert(found, 'Crawl Task not found: ' .. url)
    end

    send({
      target = msg.from,
      action = 'Remove-Crawl-Tasks-Result',
      data = 'OK'
    })
  end)

  Handlers.add('Cron', 'Cron', function (msg)
    ACL.assertHasOneOfRole(msg.from, { 'owner', 'admin', 'Cron' })

    CronTick()
  end)

  Handlers.add('Relay-Result', 'Relay-Result', function (msg)
    assert(msg.from == id, 'Unauthorized Relay-Result Caller')
    -- print('Relay-Result msg:', require('json').encode(msg))
    if StringUtils.starts_with(msg['content-type'], 'text/html') then
      print('Parsing HTML for url: ' .. tostring(msg['relay-path']))
      local parsed = ParseHTML(msg.body)
      print('Got links from html parse:', require('json').encode(parsed.links))
      local links = utils.map(
        function (link)
          if StringUtils.starts_with(link, '/') then
            local parsedUrl = neturl.parse(msg['relay-path']):normalize()
            local protocol = parsedUrl.scheme
            local domain = parsedUrl.host or parsedUrl.authority
            return protocol .. '://' .. domain .. link
          elseif StringUtils.starts_with(link, 'http://') or
                 StringUtils.starts_with(link, 'https://') or
                 StringUtils.starts_with(link, 'ar://') or
                 StringUtils.starts_with(link, 'arns://') then
            return link
          else
            -- relative link
            local parsedUrl = neturl.parse(msg['relay-path']):normalize()
            local protocol = parsedUrl.scheme
            local domain = parsedUrl.host or parsedUrl.authority
            local path = parsedUrl.path
            if path:sub(-1) == '/' then
              path = path:sub(1, -2)
            end
            local basePath = path:match('(.*/)')
            if not basePath then
              basePath = '/'
            end
            return protocol .. '://' .. domain .. basePath .. link

          end

          return link
        end,
        parsed.links
      )
      print('Normalized links:', require('json').encode(links))

      -- s="Sat, 29 Oct 1994 19:43:31 GMT"
      -- local date = msg['date'] or ''
      -- local pattern = '%a+, (%d+) (%a+) (%d+) (%d+):(%d+):(%d+) GMT'
      -- local day,month,year,hour,min,sec=date:match(pattern)
      -- MON={Jan=1,Feb=2,Mar=3,Apr=4,May=5,Jun=6,Jul=7,Aug=8,Sep=9,Oct=10,Nov=11,Dec=12}
      -- month=MON[month]
      -- local lastCrawledAt = tostring(os.time({day=day,month=month,year=year,hour=hour,min=min,sec=sec}))
      -- print('using last crawled at: ' .. msg['date'])
      for _, url in ipairs(links) do
        print('Discovered link:', url)
        if utils.includes(url, WuzzyCrawler.State.CrawledURLs) then
          print('Already crawled:', url)
        elseif not IsInCrawlTaskDomains(url) then
          print('Not in crawl tasks:', url)
        else
          local result, err = EnqueueCrawl(url)
          if err then print('Enqueue Crawled Link Error:', err) end
          if result then print('Enqueue Crawled Link Result:', result) end
        end
      end
      if (type(parsed.content) == 'string' and parsed.content ~= '') then
        print('Submitting parsed HTML content with length ' .. tostring(#parsed.content))
        SubmitDocument({
          Id = msg['relay-path'],
          URL = msg['relay-path'],
          ContentType = msg['content-type'],
          LastCrawledAt = msg['date'],
          Content = parsed.content,
          Title = parsed.title,
          Description = parsed.description,
          Links = parsed.links
        })
      else
        print('No content extracted from HTML for url:', msg['relay-path'])
      end

    elseif StringUtils.starts_with(msg['content-type'], 'text/plain') then
      SubmitDocument({
        Id = msg['relay-path'],
        URL = msg['relay-path'],
        ContentType = msg['content-type'],
        LastCrawledAt = msg['date'],
        Content = msg.body
      })
    else
      print(
        'Ignoring url: ' .. tostring(msg['relay-path']) ..
        ' with content-type: ' .. tostring(msg['content-type'])
      )
    end
  end)

  Handlers.add('Set-Nest-Id', 'Set-Nest-Id', function (msg)
    ACL.assertHasOneOfRole(msg.from, { 'owner', 'admin', 'Set-Nest-Id' })
    assert(
      type(msg['nest-id']) == 'string' and msg['nest-id'] ~= '',
      'Missing Nest-Id'
    )

    WuzzyCrawler.State.NestId = msg['nest-id']

    send({
      target = msg.from,
      action = 'Set-Nest-Id-Result',
      data = 'OK',
      ['nest-id'] = WuzzyCrawler.State.NestId
    })
  end)

  Handlers.add('Set-Gateway', 'Set-Gateway', function (msg)
    ACL.assertHasOneOfRole(msg.from, { 'owner', 'admin', 'Set-Gateway' })
    assert(
      type(msg['gateway']) == 'string' and msg['gateway'] ~= '',
      'Missing Gateway'
    )

    WuzzyCrawler.State.Gateway = msg['gateway']

    send({
      target = msg.from,
      action = 'Set-Gateway-Result',
      data = 'OK',
      ['gateway'] = WuzzyCrawler.State.Gateway
    })
  end)

  function DequeueCrawl(url)
    local relayPath = url

    if StringUtils.starts_with(url, 'arns://') then
      local parsed = neturl.parse(url)
      local domain = parsed.host or parsed.authority
      local path = parsed.path
      local parsedGateway = neturl.parse(WuzzyCrawler.State.Gateway)
      local gatewayDomain = parsedGateway.host or parsedGateway.authority
      local gatewayPort = parsedGateway.port and (':' .. tostring(parsedGateway.port)) or ''
      relayPath = 'https://' .. domain .. '.' .. gatewayDomain .. gatewayPort
      if path and path ~= '' then
        relayPath = relayPath .. path
      end
    elseif StringUtils.starts_with(url, 'ar://') then
      local parsed = neturl.parse(url)
      local txid = parsed.host or parsed.authority
      local path = parsed.path
      relayPath = WuzzyCrawler.State.Gateway .. '/' .. txid
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

    for i, task in ipairs(WuzzyCrawler.State.CrawlQueue) do
      if task.URL == url then
        table.remove(WuzzyCrawler.State.CrawlQueue, i)
        table.insert(
          WuzzyCrawler.State.CrawledURLs,
          url
        )
        break
      end
    end

    return 'Crawled ' .. url
  end

  function EnqueueCrawl(url)
    local parsedUrl = neturl.parse(url):normalize()
    local protocol = parsedUrl.scheme
    local domain = parsedUrl.host or parsedUrl.authority
    local path = parsedUrl.path
    if protocol and domain and path then
      if utils.includes(protocol, { 'http', 'https', 'arns', 'ar' }) then
        local baseUrl = protocol .. '://' .. domain .. path
        local existingQueueItem = utils.find(
          function(item) return item.URL == baseUrl end,
          WuzzyCrawler.State.CrawlQueue
        )
        if existingQueueItem then
          return 'URL already in crawl queue: ' .. baseUrl
        end
        local existingMemoryItem = utils.find(
          function(item) return item == baseUrl end,
          WuzzyCrawler.State.CrawledURLs
        )
        if existingMemoryItem then
          return 'URL already crawled this run: ' .. baseUrl
        end

        table.insert(WuzzyCrawler.State.CrawlQueue, {
          SubmittedUrl = url,
          URL = baseUrl,
          Protocol = protocol,
          Domain = domain,
          Path = path
        })

        return 'URL added to crawl queue: ' .. baseUrl
      else
        return nil, 'Unsupported Crawl Task Protocol: ' .. url
      end
    else
      return nil, 'Invalid URL: ' .. url
    end
  end

  function SubmitDocument(document)
    print('Submitting Document ' .. document.Id .. ' to Nest ' .. WuzzyCrawler.State.NestId)
    send({
      target = WuzzyCrawler.State.NestId,
      action = 'Index-Document',
      data = document.Content,
      ['document-last-crawled-at'] = document.LastCrawledAt,
      ['document-url'] = document.URL,
      ['document-content-type'] = document.ContentType,
      ['document-title'] = document.Title,
      ['document-description'] = document.Description
    })
  end

  function ParseHTML(html)
    local root = HtmlParser.parse(html, 10000)
    local titleElement = root:select('title')[1]
    local title = titleElement and titleElement:getcontent() or ''
    local descElement = root:select('meta[name="description"]')[1]
    local description =
      descElement and descElement.attributes['content'] or ''
    description = description:sub(1, 250)
    local anchorElements = root:select('a')
    local links = {}
    for _, anchor in ipairs(anchorElements) do
      local parsedUrl = neturl.parse(anchor.attributes['href']):normalize()
      parsedUrl:setQuery{}
      parsedUrl.fragment = nil
      local href = tostring(parsedUrl)
      if href:sub(-1) == '/' then
        href = href:sub(1, -2)
      end
      
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

    -- Remove script tags and their content (case-insensitive)
    content = content:gsub('<[Ss][Cc][Rr][Ii][Pp][Tt][^>]*>.-</[Ss][Cc][Rr][Ii][Pp][Tt]>', ' ')

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
    content = content:gsub('&ndash;', '-')
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

  function IsInCrawlTaskDomains(url)
    local parsedUrl = neturl.parse(url):normalize()
    local domain = parsedUrl.host or parsedUrl.authority
    local crawlTaskDomains = utils.map(
      function(task)
        return task.Domain
      end,
      WuzzyCrawler.State.CrawlTasks
    )

    -- print('checking ' .. url .. ' with domain ' .. domain .. ' is in ' .. require('json').encode(crawlTaskDomains))

    if domain and utils.includes(domain, crawlTaskDomains) then
      return true
    end

    return false
  end

  function CronTick()
    if #WuzzyCrawler.State.CrawlQueue < 1 then
      print('Nothing in Crawl Queue')

      if #WuzzyCrawler.State.CrawlTasks < 1 then
        print('No Crawl Tasks to process')
        return
      end

      print('Processing Crawl Tasks: ' .. #WuzzyCrawler.State.CrawlTasks)
      WuzzyCrawler.State.CrawledURLs = {}
      for _, task in ipairs(WuzzyCrawler.State.CrawlTasks) do
        print('Enqueue Crawl: ' .. task.URL)
        local result, err = EnqueueCrawl(task.URL)
        if err then print('Enqueue Crawl Error:', err) end
        if result then print('Enqueue Crawl Result:', result) end
      end
    end

    print('Processing Crawl Queue: ' .. #WuzzyCrawler.State.CrawlQueue)
    if #WuzzyCrawler.State.CrawlQueue > 0 then
      local result, err = DequeueCrawl(
        WuzzyCrawler.State.CrawlQueue[1].URL
      )
      if err then print('Dequeue Crawl Error:', err) end
      if result then print('Dequeue Crawl Result:', result) end
    end
  end

  WuzzyCrawler.State.Initialized = true

  Handlers.add(
    'Owner-Fallback',
    function(msg) return msg.from == owner end,
    function (msg)
      CronTick()
    end
  )
end

if not WuzzyCrawler.State.Initialized then
  WuzzyCrawler.init()
end
