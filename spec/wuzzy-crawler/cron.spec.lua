local codepath = 'wuzzy-crawler.wuzzy-crawler'

describe('Wuzzy-Crawler Cron', function()
  local utils = require('.utils')
  local WuzzyCrawler = require(codepath)
  before_each(function()
    CacheOriginalGlobals()
    WuzzyCrawler = require(codepath)
  end)
  after_each(function()
    RestoreOriginalGlobals()
    package.loaded[codepath] = nil
    package.loaded['..common.acl'] = nil
  end)

  it('ignores unknown Cron messages', function()
    _G.send = spy.new(function() end)
    assert.has_error(function()
      GetHandler('Cron').handle({ from = _G.owner })
    end, 'Unauthorized Cron Caller')
  end)

  it('does nothing it if has no Crawl Tasks', function()
    _G.send = spy.new(function() end)
    WuzzyCrawler.enqueueCrawl = spy.new(function() end)
    WuzzyCrawler.dequeueCrawl = spy.new(function() end)
    GetHandler('Cron').handle({ from = _G.authorities[1] })
    assert.spy(WuzzyCrawler.enqueueCrawl).was.called(0)
  end)

  it('queues all assigned Crawl Tasks if queue is empty', function()
    _G.send = spy.new(function() end)
    WuzzyCrawler.enqueueCrawl = spy.new(function() end)
    WuzzyCrawler.dequeueCrawl = spy.new(function() end)
    local tasks = {
        'arns://memeticblock',
        'arns://wuzzy'
    }
    GetHandler('Add-Crawl-Tasks').handle({
      from = _G.owner,
      data = tasks[1] .. '\n' .. tasks[2]
    })

    GetHandler('Cron').handle({ from = _G.authorities[1] })
    assert.spy(WuzzyCrawler.enqueueCrawl).was.called(2)
    assert.spy(WuzzyCrawler.enqueueCrawl).was.called_with(tasks[1])
    assert.spy(WuzzyCrawler.enqueueCrawl).was.called_with(tasks[2])
  end)

  it('processes a queue item each Cron call, if any', function()
    _G.send = spy.new(function() end)
    local dequeueCrawlSpy = spy.on(WuzzyCrawler, 'dequeueCrawl')
    local tasks = {
      'arns://memeticblock',
      'arns://wuzzy',
      'arns://cookbook',
      'arns://cookbook_ao'
    }
    GetHandler('Add-Crawl-Tasks').handle({
      from = _G.owner,
      data = tasks[1] .. '\n' ..
        tasks[2] .. '\n' ..
        tasks[3] .. '\n' ..
        tasks[4]
    })

    GetHandler('Cron').handle({ from = _G.authorities[1] })
    assert.spy(dequeueCrawlSpy).was.called(1)
    assert(#utils.keys(WuzzyCrawler.State.CrawlQueue) == 3)

    GetHandler('Cron').handle({ from = _G.authorities[1] })
    assert.spy(dequeueCrawlSpy).was.called(2)
    assert(#utils.keys(WuzzyCrawler.State.CrawlQueue) == 2)

    GetHandler('Cron').handle({ from = _G.authorities[1] })
    assert.spy(dequeueCrawlSpy).was.called(3)
    assert(#utils.keys(WuzzyCrawler.State.CrawlQueue) == 1)

    GetHandler('Cron').handle({ from = _G.authorities[1] })
    assert.spy(dequeueCrawlSpy).was.called(4)
    assert(#utils.keys(WuzzyCrawler.State.CrawlQueue) == 0)

    assert.is_nil(WuzzyCrawler.State.CrawlQueue[tasks[1]])
    assert.is_nil(WuzzyCrawler.State.CrawlQueue[tasks[2]])
    assert.is_nil(WuzzyCrawler.State.CrawlQueue[tasks[3]])
    assert.is_nil(WuzzyCrawler.State.CrawlQueue[tasks[4]])
  end)

  pending('uses ~patch@1.0 whenever updating state', function() end)
  pending('only queues Crawl Tasks if enough time has elapsed', function() end)
  pending('clears url crawl memory when queueing Crawl Tasks', function() end)
end)
