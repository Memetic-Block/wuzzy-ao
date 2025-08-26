local codepath = 'wuzzy-nest.wuzzy-nest'

describe('Wuzzy-Nest Initialization', function ()
  _G.send = spy.new(function() end)
  local WuzzyNest = require(codepath)
  before_each(function()
    CacheOriginalGlobals()
    _G.send = spy.new(function() end)
    WuzzyNest = require(codepath)
  end)
  after_each(function()
    RestoreOriginalGlobals()
    _G.send = spy.new(function() end)
    package.loaded[codepath] = nil
  end)

  it('should initialize with ~patch@1.0', function ()
    _G.send = spy.new(function() end)
    package.loaded[codepath] = nil
    WuzzyNest = require(codepath)

    assert.is_true(WuzzyNest.State.Initialized)
    assert.spy(_G.send).was.called_with({
      device = 'patch@1.0',
      cache = WuzzyNest.State
    })
  end)
end)
