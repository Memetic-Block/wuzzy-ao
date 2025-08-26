local codepath = 'wuzzy-crawler.wuzzy-crawler'

describe('Wuzzy-Crawler Config', function ()
  _G.send = spy.new(function() end)
  local WuzzyCrawler = require(codepath)
  before_each(function()
    CacheOriginalGlobals()
    _G.send = spy.new(function() end)
    WuzzyCrawler = require(codepath)
  end)
  after_each(function()
    RestoreOriginalGlobals()
    package.loaded[codepath] = nil
  end)

  describe('Nest-Id', function()
    it('prevents Unauthorized callers from setting Nest-Id', function()
      assert.has_error(function()
        GetHandler('Set-Nest-Id').handle({
          id = 'mock-message-id-1',
          from = 'alice-mock-address',
          target = 'wuzzy-nest-process-id',
          action = 'Set-Nest-Id'
        })
      end, 'Permission Denied')
    end)

    it('requires Nest-Id when setting', function()
      assert.has_error(function()
        GetHandler('Set-Nest-Id').handle({
          id = 'mock-message-id-1',
          from = _G.owner,
          target = 'wuzzy-nest-process-id',
          action = 'Set-Nest-Id'
        })
      end, 'Missing Nest-Id')
    end)

    it('allows Authorized callers to set Nest-Id', function()
      _G.send = spy.new(function() end)
      local aliceAddress = 'alice-address'
      local bobAddress = 'bob-address'
      GetHandler('Update-Roles').handle({
        from = _G.owner,
        data = require('json').encode({
          Grant = {
            [aliceAddress] = { 'admin' },
            [bobAddress] = { 'Set-Nest-Id' }
          }
        })
      })
      _G.send:clear()

      GetHandler('Set-Nest-Id').handle({
        id = 'mock-message-id-1',
        from = _G.owner,
        target = 'wuzzy-nest-process-id',
        action = 'Set-Nest-Id',
        ['Nest-Id'] = 'nest-1'
      })
      assert.spy(_G.send).was.called(2)
      assert.spy(_G.send).was.called_with({
        target = _G.owner,
        action = 'Set-Nest-Id-Result',
        data = 'OK',
        ['Nest-Id'] = 'nest-1'
      })
      assert.spy(_G.send).was.called_with({
        device = 'patch@1.0',
        cache = WuzzyCrawler.State
      })
      _G.send:clear()

      GetHandler('Set-Nest-Id').handle({
        id = 'mock-message-id-2',
        from = aliceAddress,
        target = 'wuzzy-nest-process-id',
        action = 'Set-Nest-Id',
        ['Nest-Id'] = 'nest-2'
      })
      assert.spy(_G.send).was.called(2)
      assert.spy(_G.send).was.called_with({
        target = aliceAddress,
        action = 'Set-Nest-Id-Result',
        data = 'OK',
        ['Nest-Id'] = 'nest-2'
      })
      assert.spy(_G.send).was.called_with({
        device = 'patch@1.0',
        cache = WuzzyCrawler.State
      })
      _G.send:clear()

      -- TODO -> bob
      GetHandler('Set-Nest-Id').handle({
        id = 'mock-message-id-3',
        from = bobAddress,
        target = 'wuzzy-nest-process-id',
        action = 'Set-Nest-Id',
        ['Nest-Id'] = 'nest-3'
      })
      assert.spy(_G.send).was.called(2)
      assert.spy(_G.send).was.called_with({
        target = bobAddress,
        action = 'Set-Nest-Id-Result',
        data = 'OK',
        ['Nest-Id'] = 'nest-3'
      })
      assert.spy(_G.send).was.called_with({
        device = 'patch@1.0',
        cache = WuzzyCrawler.State
      })
      _G.send:clear()
    end)
  end)
end)
