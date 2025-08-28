local codepath = 'wuzzy-crawler.wuzzy-crawler'

describe('WuzzyCrawler Config', function ()
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
      assert.spy(_G.send).was.called(1)
      assert.spy(_G.send).was.called_with({
        target = _G.owner,
        action = 'Set-Nest-Id-Result',
        data = 'OK',
        ['Nest-Id'] = 'nest-1'
      })
      _G.send:clear()

      GetHandler('Set-Nest-Id').handle({
        id = 'mock-message-id-2',
        from = aliceAddress,
        target = 'wuzzy-nest-process-id',
        action = 'Set-Nest-Id',
        ['Nest-Id'] = 'nest-2'
      })
      assert.spy(_G.send).was.called(1)
      assert.spy(_G.send).was.called_with({
        target = aliceAddress,
        action = 'Set-Nest-Id-Result',
        data = 'OK',
        ['Nest-Id'] = 'nest-2'
      })
      _G.send:clear()

      GetHandler('Set-Nest-Id').handle({
        id = 'mock-message-id-3',
        from = bobAddress,
        target = 'wuzzy-nest-process-id',
        action = 'Set-Nest-Id',
        ['Nest-Id'] = 'nest-3'
      })
      assert.spy(_G.send).was.called(1)
      assert.spy(_G.send).was.called_with({
        target = bobAddress,
        action = 'Set-Nest-Id-Result',
        data = 'OK',
        ['Nest-Id'] = 'nest-3'
      })
      _G.send:clear()
    end)
  end)

  describe('Gateway', function()
    it('prevents Unauthorized callers from setting Gateway', function()
      assert.has_error(function()
        GetHandler('Set-Gateway').handle({
          id = 'mock-message-id-1',
          from = 'alice-mock-address',
          target = 'wuzzy-nest-process-id',
          action = 'Set-Gateway'
        })
      end, 'Permission Denied')
    end)

    it('requires Gateway when setting', function()
      assert.has_error(function()
        GetHandler('Set-Gateway').handle({
          id = 'mock-message-id-1',
          from = _G.owner,
          target = 'wuzzy-nest-process-id',
          action = 'Set-Gateway'
        })
      end, 'Missing Gateway')
    end)

    it('allows Authorized callers to set Gateway', function()
      _G.send = spy.new(function() end)
      local aliceAddress = 'alice-address'
      local bobAddress = 'bob-address'
      GetHandler('Update-Roles').handle({
        from = _G.owner,
        data = require('json').encode({
          Grant = {
            [aliceAddress] = { 'admin' },
            [bobAddress] = { 'Set-Gateway' }
          }
        })
      })
      _G.send:clear()

      GetHandler('Set-Gateway').handle({
        id = 'mock-message-id-1',
        from = _G.owner,
        target = 'wuzzy-nest-process-id',
        action = 'Set-Gateway',
        ['Gateway'] = 'https://frostor.xyz'
      })
      assert.spy(_G.send).was.called(1)
      assert.spy(_G.send).was.called_with({
        target = _G.owner,
        action = 'Set-Gateway-Result',
        data = 'OK',
        ['Gateway'] = 'https://frostor.xyz'
      })
      _G.send:clear()

      GetHandler('Set-Gateway').handle({
        id = 'mock-message-id-2',
        from = aliceAddress,
        target = 'wuzzy-nest-process-id',
        action = 'Set-Gateway',
        ['Gateway'] = 'https://love4src.com'
      })
      assert.spy(_G.send).was.called(1)
      assert.spy(_G.send).was.called_with({
        target = aliceAddress,
        action = 'Set-Gateway-Result',
        data = 'OK',
        ['Gateway'] = 'https://love4src.com'
      })
      _G.send:clear()

      GetHandler('Set-Gateway').handle({
        id = 'mock-message-id-3',
        from = bobAddress,
        target = 'wuzzy-nest-process-id',
        action = 'Set-Gateway',
        ['Gateway'] = 'https://another.gateway'
      })
      assert.spy(_G.send).was.called(1)
      assert.spy(_G.send).was.called_with({
        target = bobAddress,
        action = 'Set-Gateway-Result',
        data = 'OK',
        ['Gateway'] = 'https://another.gateway'
      })
      _G.send:clear()
    end)
  end)
end)
