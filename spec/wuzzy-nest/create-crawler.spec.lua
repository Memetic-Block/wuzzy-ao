local codepath = 'wuzzy-nest.wuzzy-nest'

describe('Wuzzy-Nest Create-Crawler', function()
  local WuzzyNest = require(codepath)
  before_each(function()
    CacheOriginalGlobals()
    WuzzyNest = require(codepath)
  end)
  after_each(function()
    RestoreOriginalGlobals()
    package.loaded[codepath] = nil
  end)

  it('spawns a new Wuzzy-Crawler process & tracks the spawn', function()
    _G.send = spy.new(function() end)
    _G.spawn = spy.new(function() end)
    local handler = GetHandler('Create-Crawler')
    local msgId = 'mock-message-id-1'
    local from = _G.owner
    local crawlerName = 'My Wuzzy Crawler'

    handler.handle({
      id = msgId,
      from = from,
      target = 'wuzzy-nest-process-id',
      action = 'Create-Crawler'
    })

    assert.spy(_G.spawn).was.called_with(_G.module, {
      ['App-Name'] = 'Wuzzy',
      ['Contract-Name'] = 'wuzzy-crawler',
      authority = _G.authorities[1],
      ['X-Create-Crawler-Id'] = msgId,
      ['Crawler-Name'] = crawlerName,
      ['Crawler-Creator'] = from
    })
    assert.are_same(WuzzyNest.State.CrawlerSpawnRefs[msgId], {
      Creator = from,
      CrawlerName = crawlerName
    })
    assert.spy(_G.send).was.called_with({
      target = from,
      action = 'Create-Crawler-Result',
      data = 'OK',
      ['X-Create-Crawler-Id'] = msgId
    })
  end)

  it('notifies creator of new crawler spawn & tracks creators', function()
    _G.send = spy.new(function() end)
    _G.spawn = spy.new(function() end)
    local msgId = 'mock-message-id-1'
    local from = _G.owner
    local newCrawlerProcessId = 'new-crawler-process-id'
    local crawlerName = 'My Wuzzy Crawler'

    GetHandler('Create-Crawler').handle({
      id = msgId,
      from = from,
      target = _G.id,
      action = 'Create-Crawler'
    })
    _G.send:clear()
    _G.spawn:clear()
    GetHandler('Spawned').handle({
      id = 'mock-message-id-2',
      from = _G.id,
      target = _G.id,
      action = 'Spawned',
      ['X-Create-Crawler-Id'] = msgId,
      ['From-Process'] = _G.id,
      ['Process'] = newCrawlerProcessId
    })

    assert.spy(_G.send).was.called_with({
      target = newCrawlerProcessId,
      action = 'Eval',
      data = require('.base64').decode(
        require('..wuzzy-crawler.wuzzy-crawler-stringified')
      )
    })
    assert.are_same(WuzzyNest.State.Crawlers[newCrawlerProcessId], {
      ['X-Create-Crawler-Id'] = msgId,
      Creator = from,
      Name = crawlerName,
      Owner = from,
      Roles = {}
    })
    assert.is_nil(WuzzyNest.State.CrawlerSpawnRefs[msgId])
    assert.spy(_G.send).was.called_with({
      target = from,
      action = 'Crawler-Spawned',
      ['Crawler-Id'] = newCrawlerProcessId,
      ['X-Create-Crawler-Id'] = msgId,
      data = 'OK'
    })
  end)

  it('throws on Create-Crawler messages from unauthorized callers', function()
    assert.has.errors(function()
      GetHandler('Create-Crawler').handle({
        id = 'mock-message-id-1',
        from = 'alice-mock-address',
        target = 'wuzzy-nest-process-id',
        action = 'Create-Crawler'
      })
    end, 'Permission Denied')
  end)

  it('ignores Spawned messages without known X-Create-Crawler-Id', function()
    _G.send = spy.new(function() end)

    GetHandler('Spawned').handle({
      id = 'mock-message-id-2',
      from = _G.id,
      target = _G.id,
      action = 'Spawned',
      ['From-Process'] = _G.id,
      ['Process'] = 'new-crawler-process-id'
    })

    assert.spy(_G.send).was.called(0)
  end)

  it('ignores Spawned messages from unknown process', function()
    _G.send = spy.new(function() end)

    GetHandler('Spawned').handle({
      id = 'mock-message-id-2',
      from = _G.id,
      target = _G.id,
      action = 'Spawned',
      ['X-Create-Crawler-Id'] = 'unknown-id',
      ['From-Process'] = _G.id,
      ['Process'] = 'new-crawler-process-id'
    })

    assert.spy(_G.send).was.called(0)
  end)

  it('ignores Spawned messages from unknown caller', function()
    _G.send = spy.new(function() end)

    GetHandler('Spawned').handle({
      id = 'mock-message-id-2',
      from = 'unknown-caller-id',
      target = _G.id,
      action = 'Spawned',
      ['X-Create-Crawler-Id'] = 'unknown-id',
      ['From-Process'] = _G.id,
      ['Process'] = 'new-crawler-process-id'
    })

    assert.spy(_G.send).was.called(0)
  end)

  it('ignores Spawned messages with unknown X-Create-Crawler-Id', function()
    _G.send = spy.new(function() end)

    GetHandler('Spawned').handle({
      id = 'mock-message-id-2',
      from = _G.id,
      target = _G.id,
      action = 'Spawned',
      ['X-Create-Crawler-Id'] = 'unknown-id',
      ['From-Process'] = _G.id,
      ['Process'] = 'new-crawler-process-id'
    })

    assert.spy(_G.send).was.called(0)
  end)

  it('ignores Spawned messages without Process tag', function()
    _G.send = spy.new(function() end)
    local xCreateCrawlerId = 'mock-create-crawler-id'

    WuzzyNest.State.CrawlerSpawnRefs[xCreateCrawlerId] = {
      Creator = _G.owner,
      CrawlerName = 'My Wuzzy Crawler'
    }

    GetHandler('Spawned').handle({
      id = 'mock-message-id-2',
      from = _G.id,
      target = _G.id,
      action = 'Spawned',
      ['X-Create-Crawler-Id'] = xCreateCrawlerId,
      ['From-Process'] = _G.id,
    })

    assert.spy(_G.send).was.called(0)
  end)

  pending('uses ~patch@1.0 whenever updating state', function() end)
end)
