local codepath = 'wuzzy-nest.wuzzy-nest'

describe('WuzzyNest Crawlers', function()
  _G.send = spy.new(function() end)
  require(codepath)
  local utils = require('.utils')
  before_each(function()
    CacheOriginalGlobals()
    require(codepath)
  end)
  after_each(function()
    RestoreOriginalGlobals()
    package.loaded[codepath] = nil
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

    it('requires crawler-id when adding crawlers', function()
      assert.has_error(function()
        GetHandler('Add-Crawler').handle({
          id = 'mock-message-id-1',
          from = _G.owner,
          target = 'wuzzy-nest-process-id',
          action = 'Add-Crawler'
        })
      end, 'crawler-id is required')
    end)

    it('prevents duplicate crawler-id', function()
      _G.send = spy.new(function() end)
      GetHandler('Add-Crawler').handle({
        id = 'mock-message-id-1',
        from = _G.owner,
        target = 'wuzzy-nest-process-id',
        action = 'Add-Crawler',
        ['crawler-id'] = 'crawler-1'
      })

      assert.has_error(function()
        GetHandler('Add-Crawler').handle({
          id = 'mock-message-id-2',
          from = _G.owner,
          target = 'wuzzy-nest-process-id',
          action = 'Add-Crawler',
          ['crawler-id'] = 'crawler-1'
        })
      end, 'crawler-id already exists')
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
        ['crawler-id'] = 'crawler-1'
      })
      assert.spy(_G.send).was.called(1)
      assert.spy(_G.send).was.called_with({
        target = _G.owner,
        action = 'Crawler-Added',
        data = 'OK',
        ['crawler-id'] = 'crawler-1'
      })

      _G.send:clear()
      GetHandler('Add-Crawler').handle({
        id = 'mock-message-id-2',
        from = aliceAddress,
        target = 'wuzzy-nest-process-id',
        action = 'Add-Crawler',
        ['crawler-id'] = 'crawler-2'
      })
      assert.spy(_G.send).was.called(1)
      assert.spy(_G.send).was.called_with({
        target = aliceAddress,
        action = 'Crawler-Added',
        data = 'OK',
        ['crawler-id'] = 'crawler-2'
      })

      _G.send:clear()
      GetHandler('Add-Crawler').handle({
        id = 'mock-message-id-2',
        from = bobAddress,
        target = 'wuzzy-nest-process-id',
        action = 'Add-Crawler',
        ['crawler-id'] = 'crawler-3'
      })
      assert.spy(_G.send).was.called(1)
      assert.spy(_G.send).was.called_with({
        target = bobAddress,
        action = 'Crawler-Added',
        data = 'OK',
        ['crawler-id'] = 'crawler-3'
      })
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

    it('requires crawler-id when removing crawlers', function()
      assert.has_error(function()
        GetHandler('Remove-Crawler').handle({
          id = 'mock-message-id-1',
          from = _G.owner,
          target = 'wuzzy-nest-process-id',
          action = 'Remove-Crawler'
        })
      end, 'crawler-id is required')
    end)

    it('throws if crawler-id not found on remove', function()
      assert.has_error(function()
        GetHandler('Remove-Crawler').handle({
          id = 'mock-message-id-1',
          from = _G.owner,
          target = 'wuzzy-nest-process-id',
          action = 'Remove-Crawler',
          ['crawler-id'] = 'crawler-1'
        })
      end, 'crawler-id does not exist')
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
          ['crawler-id'] = cid
        })
      end
      _G.send:clear()

      assert(#utils.keys(WuzzyNest.State.Crawlers) == 4)

      GetHandler('Remove-Crawler').handle({
        id = 'mock-message-id-remove-1',
        from = _G.owner,
        target = 'wuzzy-nest-process-id',
        action = 'Remove-Crawler',
        ['crawler-id'] = crawlerIds[1]
      })
      assert(#utils.keys(WuzzyNest.State.Crawlers) == 3)
      assert.is_nil(WuzzyNest.State.Crawlers[crawlerIds[1]])
      assert.spy(_G.send).was.called(1)
      assert.spy(_G.send).was.called_with({
        target = _G.owner,
        action = 'Crawler-Removed',
        data = 'OK',
        ['crawler-id'] = crawlerIds[1]
      })
      _G.send:clear()

      -- TODO -> alice admin
      GetHandler('Remove-Crawler').handle({
        id = 'mock-message-id-remove-2',
        from = aliceAddress,
        target = 'wuzzy-nest-process-id',
        action = 'Remove-Crawler',
        ['crawler-id'] = crawlerIds[2]
      })
      assert(#utils.keys(WuzzyNest.State.Crawlers) == 2)
      assert.is_nil(WuzzyNest.State.Crawlers[crawlerIds[2]])
      assert.spy(_G.send).was.called(1)
      assert.spy(_G.send).was.called_with({
        target = aliceAddress,
        action = 'Crawler-Removed',
        data = 'OK',
        ['crawler-id'] = crawlerIds[2]
      })
      _G.send:clear()

      -- TODO -> bob acl
      GetHandler('Remove-Crawler').handle({
        id = 'mock-message-id-remove-3',
        from = bobAddress,
        target = 'wuzzy-nest-process-id',
        action = 'Remove-Crawler',
        ['crawler-id'] = crawlerIds[3]
      })
      assert(#utils.keys(WuzzyNest.State.Crawlers) == 1)
      assert.is_nil(WuzzyNest.State.Crawlers[crawlerIds[3]])
      assert.spy(_G.send).was.called(1)
      assert.spy(_G.send).was.called_with({
        target = bobAddress,
        action = 'Crawler-Removed',
        data = 'OK',
        ['crawler-id'] = crawlerIds[3]
      })
      _G.send:clear()
    end)
  end)
end)
