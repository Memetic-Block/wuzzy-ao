local codepath = 'wuzzy-nest-registry.wuzzy-nest-registry'

describe('WuzzyNestRegistry Initialization', function ()
  _G.send = spy.new(function() end)
  require(codepath)
  before_each(function()
    CacheOriginalGlobals()
    _G.send = spy.new(function() end)
    require(codepath)
  end)
  after_each(function()
    RestoreOriginalGlobals()
    _G.send = spy.new(function() end)
    package.loaded[codepath] = nil
  end)

  it('should initialize', function ()
    _G.send = spy.new(function() end)
    package.loaded[codepath] = nil
    require(codepath)

    assert.is_true(WuzzyNestRegistry.State.Initialized)
  end)
end)
