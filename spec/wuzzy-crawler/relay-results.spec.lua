local codepath = 'wuzzy-crawler.wuzzy-crawler'

describe('Wuzzy-Crawler Relay-Result', function()
  local WuzzyCrawler = require(codepath)
  local utils = require('.utils')
  local StringUtils = require('common.strings')
  before_each(function()
    CacheOriginalGlobals()
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
    local body = '<html><body>some <em>html</em> content</body></html>'
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
      ['Document-Content-Type'] = contentType
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
    GetHandler('Relay-Result').handle({
      from = _G.id,
      body = _G.CookbookHtmlContent,
      ['relay-path'] = url,
      ['content-type'] = 'text/html',
      ['block-timestamp'] = tostring(os.time())
    })

    local crawlQueueItems = utils.keys(WuzzyCrawler.State.CrawlQueue)
    assert(#crawlQueueItems == #_G.CookbookLinks)
    for _, link in ipairs(_G.CookbookLinks) do
      local normalizedLink = link
      if StringUtils.starts_with(link, '/') then
        normalizedLink = url .. link
      end
      assert(
        utils.includes(normalizedLink, crawlQueueItems),
        'Missing link in crawl queue: ' .. link
      )
    end
  end)

  pending('normalizes discovered links', function() end)
  pending('doesn\'t re-crawl already crawled URLs', function() end)
end)
