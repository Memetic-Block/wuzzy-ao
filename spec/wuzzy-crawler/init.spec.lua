local codepath = 'wuzzy-crawler.wuzzy-crawler'

describe('Wuzzy-Crawler Initialization', function ()
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

  it('should initialize with ~patch@1.0', function ()
    _G.send = spy.new(function() end)
    package.loaded[codepath] = nil
    WuzzyCrawler = require(codepath)

    assert.is_true(WuzzyCrawler.State.Initialized)
    assert.spy(_G.send).was.called_with({
      device = 'patch@1.0',
      cache = WuzzyCrawler.State
    })
  end)

  it('initially sets Nest-Id to tag value if present', function()
    local nestId = 'custom-nest-id-123'
    _G.process = {
      Tags = {
        ['Nest-Id'] = nestId
      }
    }
    _G.send = spy.new(function() end)
    package.loaded[codepath] = nil
    WuzzyCrawler = require(codepath)
    assert(WuzzyCrawler.State.NestId == nestId)
  end)

  it('initially sets Nest-Id to itself if no Nest-Id tag', function()
    _G.process = {
      Tags = {}
    }
    _G.send = spy.new(function() end)
    package.loaded[codepath] = nil
    WuzzyCrawler = require(codepath)

    assert(WuzzyCrawler.State.NestId == _G.id)
  end)
end)
