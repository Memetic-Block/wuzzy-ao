local codepath = 'wuzzy-crawler.wuzzy-crawler'

describe('WuzzyCrawler Initialization', function ()
  _G.send = spy.new(function() end)
  require(codepath)
  before_each(function()
    CacheOriginalGlobals()
    _G.send = spy.new(function() end)
    require(codepath)
  end)
  after_each(function()
    RestoreOriginalGlobals()
    package.loaded[codepath] = nil
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
    require(codepath)
    assert(WuzzyCrawler.State.NestId == nestId)
  end)

  it('initially sets Nest-Id to itself if no Nest-Id tag', function()
    _G.process = {
      Tags = {}
    }
    _G.send = spy.new(function() end)
    package.loaded[codepath] = nil
    require(codepath)

    assert(WuzzyCrawler.State.NestId == _G.id)
  end)

  it('initially sets Gateway to tag value if present', function()
    local gateway = 'https://custom-gateway.example.com'
    _G.process = {
      Tags = {
        ['Gateway'] = gateway
      }
    }
    _G.send = spy.new(function() end)
    package.loaded[codepath] = nil
    require(codepath)
    assert(WuzzyCrawler.State.Gateway == gateway)
  end)

  it('initially sets Gateway to arweave.net if no Gateway tag', function()
    _G.process = {
      Tags = {}
    }
    _G.send = spy.new(function() end)
    package.loaded[codepath] = nil
    require(codepath)

    assert(WuzzyCrawler.State.Gateway == 'https://arweave.net')
  end)
end)
