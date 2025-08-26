local codepath = 'wuzzy-crawler.wuzzy-crawler'

describe('Wuzzy-Crawler Parsing', function()
  _G.send = spy.new(function() end)
  local WuzzyCrawler = require(codepath)
  local utils = require('.utils')
  before_each(function()
    CacheOriginalGlobals()
    _G.send = spy.new(function() end)
    WuzzyCrawler = require(codepath)
  end)
  after_each(function()
    RestoreOriginalGlobals()
    package.loaded[codepath] = nil
  end)

  it('extracts plaintext, title, description, and links from HTML', function()
    local title =
      'Cooking with the Permaweb | Cooking with the Permaweb'
    local desc =
      'A collection of little developer guides to build on the permaweb'

    local result = WuzzyCrawler.parseHTML(_G.CookbookHtmlContent)

    assert(result.content ~= nil, 'Failed to parse HTML')
    assert(result.content ~= _G.CookbookHtmlContent)
    assert(result.title == title, 'Failed to extract title')
    assert(result.description == desc, 'Failed to extract meta description')
    assert(#result.links == #_G.CookbookLinks, 'Failed to extract links')
    for _, link in ipairs(_G.CookbookLinks) do
      assert(
        utils.includes(link, result.links),
        'Failed to extract link: ' .. link
      )
    end
  end)
end)
