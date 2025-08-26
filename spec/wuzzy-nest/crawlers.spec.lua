local codepath = 'wuzzy-nest.wuzzy-nest'

describe('Wuzzy-Nest Crawlers', function()
  _G.send = spy.new(function() end)
  local WuzzyNest = require(codepath)
  local utils = require('.utils')
  before_each(function()
    CacheOriginalGlobals()
    WuzzyNest = require(codepath)
  end)
  after_each(function()
    RestoreOriginalGlobals()
    package.loaded[codepath] = nil
  end)

  describe('Create-Crawler', function()
    it('spawns a new Wuzzy-Crawler process & tracks the spawn', function()
      _G.send = spy.new(function() end)
      _G.spawn = spy.new(function() end)
      local msgId = 'mock-message-id-1'
      local from = _G.owner
      local crawlerName = 'My Wuzzy Crawler'

      GetHandler('Create-Crawler').handle({
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
      assert.spy(_G.send).was.called_with({
        device = 'patch@1.0',
        cache = WuzzyNest.State
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
        Owner = from
      })
      assert.is_nil(WuzzyNest.State.CrawlerSpawnRefs[msgId])
      assert.spy(_G.send).was.called_with({
        target = from,
        action = 'Crawler-Spawned',
        ['Crawler-Id'] = newCrawlerProcessId,
        ['X-Create-Crawler-Id'] = msgId,
        data = 'OK'
      })
      assert.spy(_G.send).was.called_with({
        device = 'patch@1.0',
        cache = WuzzyNest.State
      })
      assert(WuzzyNest.ACL.State.Roles['Index-Document'][newCrawlerProcessId])
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
  end)

  describe('Add-Crawler', function()
    it('prevents unauthorized callers from adding crawlers', function()
      assert.has_error(function()
        GetHandler('Add-Crawler').handle({
          id = 'mock-message-id-1',
          from = 'alice-mock-address',
          target = 'wuzzy-nest-process-id',
          action = 'Add-Crawler'
        })
      end, 'Permission Denied')
    end)

    it('requires Crawler-Id when adding crawlers', function()
      assert.has_error(function()
        GetHandler('Add-Crawler').handle({
          id = 'mock-message-id-1',
          from = _G.owner,
          target = 'wuzzy-nest-process-id',
          action = 'Add-Crawler'
        })
      end, 'Crawler-Id is required')
    end)

    it('prevents duplicate Crawler-Id', function()
      _G.send = spy.new(function() end)
      GetHandler('Add-Crawler').handle({
        id = 'mock-message-id-1',
        from = _G.owner,
        target = 'wuzzy-nest-process-id',
        action = 'Add-Crawler',
        ['Crawler-Id'] = 'crawler-1'
      })

      assert.has_error(function()
        GetHandler('Add-Crawler').handle({
          id = 'mock-message-id-2',
          from = _G.owner,
          target = 'wuzzy-nest-process-id',
          action = 'Add-Crawler',
          ['Crawler-Id'] = 'crawler-1'
        })
      end, 'Crawler-Id already exists')
    end)

    it('allows authorized callers to add crawlers', function()
      _G.send = spy.new(function() end)
      local aliceAddress = 'alice-address'
      local bobAddress = 'bob-address'
      GetHandler('Update-Roles').handle({
        from = _G.owner,
        data = require('json').encode({
          Grant = {
            [aliceAddress] = { 'admin' },
            [bobAddress] = { 'Add-Crawler' }
          }
        })
      })
      _G.send:clear()

      GetHandler('Add-Crawler').handle({
        id = 'mock-message-id-1',
        from = _G.owner,
        target = 'wuzzy-nest-process-id',
        action = 'Add-Crawler',
        ['Crawler-Id'] = 'crawler-1'
      })
      assert.spy(_G.send).was.called(2)
      assert.spy(_G.send).was.called_with({
        target = _G.owner,
        action = 'Crawler-Added',
        data = 'OK',
        ['Crawler-Id'] = 'crawler-1'
      })
      assert.spy(_G.send).was.called_with({
        device = 'patch@1.0',
        cache = WuzzyNest.State
      })

      _G.send:clear()
      GetHandler('Add-Crawler').handle({
        id = 'mock-message-id-2',
        from = aliceAddress,
        target = 'wuzzy-nest-process-id',
        action = 'Add-Crawler',
        ['Crawler-Id'] = 'crawler-2'
      })
      assert.spy(_G.send).was.called(2)
      assert.spy(_G.send).was.called_with({
        target = aliceAddress,
        action = 'Crawler-Added',
        data = 'OK',
        ['Crawler-Id'] = 'crawler-2'
      })
      assert.spy(_G.send).was.called_with({
        device = 'patch@1.0',
        cache = WuzzyNest.State
      })

      -- TODO -> bob as acl
      _G.send:clear()
      GetHandler('Add-Crawler').handle({
        id = 'mock-message-id-2',
        from = bobAddress,
        target = 'wuzzy-nest-process-id',
        action = 'Add-Crawler',
        ['Crawler-Id'] = 'crawler-3'
      })
      assert.spy(_G.send).was.called(2)
      assert.spy(_G.send).was.called_with({
        target = bobAddress,
        action = 'Crawler-Added',
        data = 'OK',
        ['Crawler-Id'] = 'crawler-3'
      })
      assert.spy(_G.send).was.called_with({
        device = 'patch@1.0',
        cache = WuzzyNest.State
      })

      assert(WuzzyNest.ACL.State.Roles['Index-Document']['crawler-1'])
      assert(WuzzyNest.ACL.State.Roles['Index-Document']['crawler-2'])
      assert(WuzzyNest.ACL.State.Roles['Index-Document']['crawler-3'])
    end)
  end)

  describe('Remove-Crawler', function()
    it('prevents unauthorized callers from removing crawlers', function()
      assert.has_error(function()
        GetHandler('Remove-Crawler').handle({
          id = 'mock-message-id-1',
          from = 'alice-mock-address',
          target = 'wuzzy-nest-process-id',
          action = 'Remove-Crawler'
        })
      end, 'Permission Denied')
    end)

    it('requires Crawler-Id when removing crawlers', function()
      assert.has_error(function()
        GetHandler('Remove-Crawler').handle({
          id = 'mock-message-id-1',
          from = _G.owner,
          target = 'wuzzy-nest-process-id',
          action = 'Remove-Crawler'
        })
      end, 'Crawler-Id is required')
    end)

    it('throws if Crawler-Id not found on remove', function()
      assert.has_error(function()
        GetHandler('Remove-Crawler').handle({
          id = 'mock-message-id-1',
          from = _G.owner,
          target = 'wuzzy-nest-process-id',
          action = 'Remove-Crawler',
          ['Crawler-Id'] = 'crawler-1'
        })
      end, 'Crawler-Id does not exist')
    end)

    it('allows authorized callers to remove crawlers', function()
      _G.send = spy.new(function() end)
      local aliceAddress = 'alice-address'
      local bobAddress = 'bob-address'
      GetHandler('Update-Roles').handle({
        from = _G.owner,
        data = require('json').encode({
          Grant = {
            [aliceAddress] = { 'admin' },
            [bobAddress] = { 'Remove-Crawler' }
          }
        })
      })
      local crawlerIds = { 'crawler-1', 'crawler-2', 'crawler-3', 'crawler-4' }
      for i, cid in ipairs(crawlerIds) do
        GetHandler('Add-Crawler').handle({
          id = 'mock-message-id-' .. i,
          from = _G.owner,
          target = 'wuzzy-nest-process-id',
          action = 'Add-Crawler',
          ['Crawler-Id'] = cid
        })
      end
      _G.send:clear()

      assert(#utils.keys(WuzzyNest.State.Crawlers) == 4)

      GetHandler('Remove-Crawler').handle({
        id = 'mock-message-id-remove-1',
        from = _G.owner,
        target = 'wuzzy-nest-process-id',
        action = 'Remove-Crawler',
        ['Crawler-Id'] = crawlerIds[1]
      })
      assert(#utils.keys(WuzzyNest.State.Crawlers) == 3)
      assert.is_nil(WuzzyNest.State.Crawlers[crawlerIds[1]])
      assert.spy(_G.send).was.called(2)
      assert.spy(_G.send).was.called_with({
        target = _G.owner,
        action = 'Crawler-Removed',
        data = 'OK',
        ['Crawler-Id'] = crawlerIds[1]
      })
      assert.spy(_G.send).was.called_with({
        device = 'patch@1.0',
        cache = WuzzyNest.State
      })
      _G.send:clear()

      -- TODO -> alice admin
      GetHandler('Remove-Crawler').handle({
        id = 'mock-message-id-remove-2',
        from = aliceAddress,
        target = 'wuzzy-nest-process-id',
        action = 'Remove-Crawler',
        ['Crawler-Id'] = crawlerIds[2]
      })
      assert(#utils.keys(WuzzyNest.State.Crawlers) == 2)
      assert.is_nil(WuzzyNest.State.Crawlers[crawlerIds[2]])
      assert.spy(_G.send).was.called(2)
      assert.spy(_G.send).was.called_with({
        target = aliceAddress,
        action = 'Crawler-Removed',
        data = 'OK',
        ['Crawler-Id'] = crawlerIds[2]
      })
      assert.spy(_G.send).was.called_with({
        device = 'patch@1.0',
        cache = WuzzyNest.State
      })
      _G.send:clear()

      -- TODO -> bob acl
      GetHandler('Remove-Crawler').handle({
        id = 'mock-message-id-remove-3',
        from = bobAddress,
        target = 'wuzzy-nest-process-id',
        action = 'Remove-Crawler',
        ['Crawler-Id'] = crawlerIds[3]
      })
      assert(#utils.keys(WuzzyNest.State.Crawlers) == 1)
      assert.is_nil(WuzzyNest.State.Crawlers[crawlerIds[3]])
      assert.spy(_G.send).was.called(2)
      assert.spy(_G.send).was.called_with({
        target = bobAddress,
        action = 'Crawler-Removed',
        data = 'OK',
        ['Crawler-Id'] = crawlerIds[3]
      })
      assert.spy(_G.send).was.called_with({
        device = 'patch@1.0',
        cache = WuzzyNest.State
      })
      _G.send:clear()
    end)
  end)
end)
