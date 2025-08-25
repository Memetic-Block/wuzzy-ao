local codepath = 'wuzzy-nest.wuzzy-nest'

describe('Wuzzy-Nest Initialization', function ()
  local WuzzyNest = require(codepath)
  before_each(function()
    CacheOriginalGlobals()
    WuzzyNest = require(codepath)
  end)
  after_each(function()
    RestoreOriginalGlobals()
    package.loaded[codepath] = nil
  end)

  it('should initialize and respond to View-State', function ()
    _G.send = spy.new(function() end)
    local handler = GetHandler('View-State')
    local from = 'tester'

    handler.handle({ from = from })

    assert.spy(_G.send).was.called_with({
      target = from,
      action = 'View-State-Response',
      data = require('json').encode(WuzzyNest.State)
    })
  end)
end)
