local codepath = 'wuzzy-crawler.wuzzy-crawler'

describe('Wuzzy-Crawler Initialization', function ()
  local WuzzyCrawler = require(codepath)
  before_each(function()
    CacheOriginalGlobals()
    WuzzyCrawler = require(codepath)
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
      data = require('json').encode(WuzzyCrawler.State)
    })
  end)
end)
