local codepath = 'wuzzy-crawler.wuzzy-crawler'

describe('Wuzzy-Crawler Relay-Result', function()
  _G.send = spy.new(function() end)
  local WuzzyCrawler = require(codepath)
  local utils = require('.utils')
  local StringUtils = require('common.strings')
  before_each(function()
    CacheOriginalGlobals()
    _G.send = spy.new(function() end)
    WuzzyCrawler = require(codepath)
  end)
  after_each(function()
    RestoreOriginalGlobals()
    package.loaded[codepath] = nil
  end)

  it('ignores Relay-Result messages not from self', function()
    assert.has_error(function()
      GetHandler('Relay-Result').handle({ from = _G.owner })
    end, 'Unauthorized Relay-Result Caller')
  end)

  it('parses html and submits crawled documents', function()
    _G.send = spy.new(function() end)
    local parseHtmlSpy = spy.on(WuzzyCrawler, 'parseHTML')
    local relayPath = 'https://example.com/some/path'
    local contentType = 'text/html'
    local title = 'Page Title'
    local desc = 'Page Description'
    local body = [[
    <html>
      <head>
        <title>]]..title..[[</title>
        <meta name="description" content="]]..desc..[[">
      </head>
      <body>
        <p>some <em>html</em> content</p>
      </body>
    </html>
    ]]
    local expectedContent = 'some html content'
    local now = tostring(os.time())
    GetHandler('Relay-Result').handle({
      from = _G.id,
      body = body,
      ['relay-path'] = relayPath,
      ['content-type'] = contentType,
      ['block-timestamp'] = now
    })

    assert.spy(parseHtmlSpy).was.called_with(body)
    assert.spy(_G.send).was.called(1)
    assert.spy(_G.send).was.called_with({
      target = WuzzyCrawler.State.NestId,
      action = 'Index-Document',
      data = expectedContent,
      ['Document-Id'] = relayPath,
      ['Document-Last-Crawled-At'] = now,
      ['Document-URL'] = relayPath,
      ['Document-Content-Type'] = contentType,
      ['Document-Title'] = title,
      ['Document-Description'] = desc
    })
  end)

  it('submits plaintext crawled documents', function()
    _G.send = spy.new(function() end)
    local parseHtmlSpy = spy.on(WuzzyCrawler, 'parseHTML')
    local relayPath = 'https://example.com/some/text'
    local contentType = 'text/plain'
    local body = 'some text content'
    local now = tostring(os.time())
    GetHandler('Relay-Result').handle({
      from = _G.id,
      body = body,
      ['relay-path'] = relayPath,
      ['content-type'] = contentType,
      ['block-timestamp'] = now
    })

    assert.spy(parseHtmlSpy).was.called(0)
    assert.spy(_G.send).was.called(1)
    assert.spy(_G.send).was.called_with({
      target = WuzzyCrawler.State.NestId,
      action = 'Index-Document',
      data = body,
      ['Document-Id'] = relayPath,
      ['Document-Last-Crawled-At'] = now,
      ['Document-URL'] = relayPath,
      ['Document-Content-Type'] = contentType
    })
  end)

  it('skips unsupported content types', function()
    _G.send = spy.new(function() end)
    local parseHtmlSpy = spy.on(WuzzyCrawler, 'parseHTML')
    local relayPath = 'https://example.com/some/image'
    local contentType = 'image/png'
    local body = 'mock png content'
    local now = tostring(os.time())
    GetHandler('Relay-Result').handle({
      from = _G.id,
      body = body,
      ['relay-path'] = relayPath,
      ['content-type'] = contentType,
      ['block-timestamp'] = now
    })

    assert.spy(parseHtmlSpy).was.called(0)
    assert.spy(_G.send).was.called(0)
  end)

  it('adds discovered links to crawl queue', function()
    _G.send = spy.new(function() end)
    local url = 'https://cookbook.arweave.net'
    WuzzyCrawler.State.CrawlTasks = { url }
    WuzzyCrawler.State.CrawledURLs[url] = tostring(os.time())
    GetHandler('Relay-Result').handle({
      from = _G.id,
      body = _G.CookbookHtmlContent,
      ['relay-path'] = url,
      ['content-type'] = 'text/html',
      ['block-timestamp'] = tostring(os.time())
    })
    -- print('crawl queue:', #WuzzyCrawler.State.CrawlQueue)
    -- print('cookbook links:', #_G.CookbookLinks)
    local externalLinks = {
      "https://github.com/twilson63/permaweb-cookbook",
      "https://github.com/twilson63/permaweb-cookbook/edit/main/docs/src/index.md",
      "https://arweave.org"
    }
    assert(#WuzzyCrawler.State.CrawlQueue == #_G.CookbookLinks - #externalLinks)
    for _, link in ipairs(_G.CookbookLinks) do
      if not utils.includes(link, externalLinks) then
        local normalizedLink = link
        if StringUtils.starts_with(link, '/') then
          normalizedLink = url .. link
        end
        assert(
          utils.find(
            function(q) return q.URL == normalizedLink end,
            WuzzyCrawler.State.CrawlQueue
          ),
          'Missing link in crawl queue: ' .. link
        )
      end
    end
  end)

  it('normalizes discovered links', function()
    _G.send = spy.new(function() end)
    local enqueueCrawlSpy = spy.on(WuzzyCrawler, 'enqueueCrawl')
    local relayPath = 'https://cookbook.arweave.net'
    local url =
      'http://cookbook.arweave.net/info/path/../to/page?json=true&skip=100#mid-dle'
    local expectedUrl = 'http://cookbook.arweave.net/info/to/page'
    WuzzyCrawler.State.CrawlTasks = { relayPath }
    GetHandler('Relay-Result').handle({
      from = _G.id,
      body = [[
      <html>
        <body>
          <a href="]] .. url .. [["></a>
        </body>
      </html>
      ]],
      ['relay-path'] = relayPath,
      ['content-type'] = 'text/html',
      ['block-timestamp'] = tostring(os.time())
    })

    assert.spy(enqueueCrawlSpy).was.called(1)
    assert.spy(enqueueCrawlSpy).was.called_with(expectedUrl)
  end)

  it('doesn\'t re-crawl already crawled URLs', function()
    _G.send = spy.new(function() end)
    local enqueueCrawlSpy = spy.on(WuzzyCrawler, 'enqueueCrawl')
    local url = 'https://cookbook.arweave.net'
    WuzzyCrawler.State.CrawledURLs[url] = tostring(os.time())
    GetHandler('Relay-Result').handle({
      from = _G.id,
      body = [[
      <html>
        <body>
          <a href="]] .. url .. [["></a>
        </body>
      </html>
      ]],
      ['relay-path'] = url,
      ['content-type'] = 'text/html',
      ['block-timestamp'] = tostring(os.time())
    })

    assert.spy(enqueueCrawlSpy).was.called(0)
  end)

  it('only crawls within Crawl-Tasks domains', function()
    _G.send = spy.new(function() end)
    local enqueueCrawlSpy = spy.on(WuzzyCrawler, 'enqueueCrawl')
    local relayPath = 'https://cookbook.arweave.net'
    local otherDomainUrl = 'https://google.com/search'
    WuzzyCrawler.State.CrawledURLs[relayPath] = tostring(os.time())
    GetHandler('Relay-Result').handle({
      from = _G.id,
      body = [[
      <html>
        <body>
          <a href="]] .. otherDomainUrl .. [["></a>
        </body>
      </html>
      ]],
      ['relay-path'] = relayPath,
      ['content-type'] = 'text/html',
      ['block-timestamp'] = tostring(os.time())
    })

    assert.spy(enqueueCrawlSpy).was.called(0)
  end)
end)
