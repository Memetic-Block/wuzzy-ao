local codepath = 'wuzzy-crawler.wuzzy-crawler'

describe('Wuzzy-Crawler Crawling', function()
  local WuzzyCrawler = require(codepath)
  before_each(function()
    CacheOriginalGlobals()
    WuzzyCrawler = require(codepath)
  end)
  after_each(function()
    RestoreOriginalGlobals()
    package.loaded[codepath] = nil
  end)

  describe('Request-Crawl', function()
    it('requires URL', function()
      _G.send = spy.new(function() end)

      assert.has_error(function()
        GetHandler('Request-Crawl').handle({ from = _G.owner })
      end, 'Missing URL to crawl')
    end)

    it('prevents unauthorized crawl requests', function()
      _G.send = spy.new(function() end)

      assert.has_error(function()
        GetHandler('Request-Crawl').handle({
          from = 'alice-address',
          URL = 'https://arweave.net/info'
        })
      end, 'Permission Denied')
    end)

    it('validates URL', function()
      _G.send = spy.new(function() end)

      assert.has_error(function()
        GetHandler('Request-Crawl').handle({
          from = _G.owner,
          URL = 'invalid-url'
        })
      end, 'Invalid URL: invalid-url')
    end)

    it('validates URL protocol', function()
      _G.send = spy.new(function() end)
      local url = 'ftp://example.com/some/path'

      assert.has_error(function()
        GetHandler('Request-Crawl').handle({
          from = _G.owner,
          URL = url
        })
      end, 'Unsupported Crawl Task Protocol: ' .. url)
    end)

    it('normalizes URL', function()
      _G.send = spy.new(function() end)
      local protocol = 'https'
      local domain = 'example.com'
      local path = '/info/path'
      local baseUrl = protocol .. '://' .. domain .. path
      local url = baseUrl .. '?json=true&skip=100#middle-part'

      GetHandler('Request-Crawl').handle({
        from = _G.owner,
        URL = url
      })

      assert.spy(_G.send).was.called_with({
        target = _G.owner,
        action = 'Request-Crawl-Result',
        data = 'URL added to crawl queue: ' .. baseUrl
      })
      assert.are_same({
        SubmittedUrl = url,
        URL = baseUrl,
        Protocol = protocol,
        Domain = domain,
        Path = path
      }, WuzzyCrawler.State.CrawlQueue[baseUrl])
    end)

    it('accepts http scheme crawl requests', function()
      _G.send = spy.new(function() end)
      local protocol = 'http'
      local domain = 'example.com'
      local path = '/some/path'
      local url = protocol .. '://' .. domain .. path

      GetHandler('Request-Crawl').handle({
        from = _G.owner,
        URL = url
      })

      assert.spy(_G.send).was.called_with({
        target = _G.owner,
        action = 'Request-Crawl-Result',
        data = 'URL added to crawl queue: ' .. url
      })
      assert.are_same(WuzzyCrawler.State.CrawlQueue[url], {
        SubmittedUrl = url,
        URL = url,
        Protocol = protocol,
        Domain = domain,
        Path = path
      })
    end)

    it('accepts https scheme crawl requests', function()
      _G.send = spy.new(function() end)
      local protocol = 'https'
      local domain = 'example.com'
      local path = '/some/path'
      local url = protocol .. '://' .. domain .. path

      GetHandler('Request-Crawl').handle({
        from = _G.owner,
        URL = url
      })

      assert.spy(_G.send).was.called_with({
        target = _G.owner,
        action = 'Request-Crawl-Result',
        data = 'URL added to crawl queue: ' .. url
      })
      assert.are_same(WuzzyCrawler.State.CrawlQueue[url], {
        SubmittedUrl = url,
        URL = url,
        Protocol = protocol,
        Domain = domain,
        Path = path
      })
    end)

    it('accepts arns scheme crawl requests', function()
      _G.send = spy.new(function() end)
      local protocol = 'arns'
      local domain = 'wuzzy'
      local path = '/some/path'
      local url = protocol .. '://' .. domain .. path

      GetHandler('Request-Crawl').handle({
        from = _G.owner,
        URL = url
      })

      assert.spy(_G.send).was.called_with({
        target = _G.owner,
        action = 'Request-Crawl-Result',
        data = 'URL added to crawl queue: ' .. url
      })
      assert.are_same(WuzzyCrawler.State.CrawlQueue[url], {
        SubmittedUrl = url,
        URL = url,
        Protocol = protocol,
        Domain = domain,
        Path = path
      })
    end)

    it('accepts ar scheme crawl requests', function()
      _G.send = spy.new(function() end)
      local protocol = 'ar'
      local domain = 'mock-tx-id'
      local path = '/some/path'
      local url = protocol .. '://' .. domain .. path

      GetHandler('Request-Crawl').handle({
        from = _G.owner,
        URL = url
      })

      assert.spy(_G.send).was.called_with({
        target = _G.owner,
        action = 'Request-Crawl-Result',
        data = 'URL added to crawl queue: ' .. url
      })
      assert.are_same(WuzzyCrawler.State.CrawlQueue[url], {
        SubmittedUrl = url,
        URL = url,
        Protocol = protocol,
        Domain = domain,
        Path = path
      })
    end)

    pending('uses ~patch@1.0 whenever updating state', function() end)
  end)

  describe('Dequeue Crawl', function()
    it('requests url from ~relay@1.0', function()
      _G.send = spy.new(function() end)
      local url = 'http://example.com/some/path'
      WuzzyCrawler.State.CrawlQueue[url] = url

      WuzzyCrawler.dequeueCrawl(url)

      assert.spy(_G.send).was.called_with({
        target = _G.id,
        ['relay-path'] = url,
        resolve = '~relay@1.0/call/~patch@1.0',
        action = 'Relay-Result'
      })
      assert(WuzzyCrawler.State.CrawlQueue[url] == nil)
    end)

    it('handles arns scheme urls', function()
      _G.send = spy.new(function() end)
      local protocol = 'arns'
      local domain = 'memeticblock'
      local path = '/info'
      local url = protocol .. '://' .. domain .. path
      WuzzyCrawler.State.CrawlQueue[url] = url

      WuzzyCrawler.dequeueCrawl(url)

      assert.spy(_G.send).was.called_with({
        target = _G.id,
        ['relay-path'] = 'https://' .. domain .. '.arweave.net' .. path,
        resolve = '~relay@1.0/call/~patch@1.0',
        action = 'Relay-Result'
      })
      assert(WuzzyCrawler.State.CrawlQueue[url] == nil)
    end)

    it('handles ar scheme urls', function()
      _G.send = spy.new(function() end)
      local protocol = 'ar'
      local txid = 'mock-tx-id'
      local path = '/info'
      local url = protocol .. '://' .. txid .. path
      WuzzyCrawler.State.CrawlQueue[url] = url

      WuzzyCrawler.dequeueCrawl(url)

      assert.spy(_G.send).was.called_with({
        target = _G.id,
        ['relay-path'] = 'https://arweave.net/' .. txid .. path,
        resolve = '~relay@1.0/call/~patch@1.0',
        action = 'Relay-Result'
      })
      assert(WuzzyCrawler.State.CrawlQueue[url] == nil)
    end)

    pending('uses ~patch@1.0 whenever updating state', function() end)
  end)
end)
