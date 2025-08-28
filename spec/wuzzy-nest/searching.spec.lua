local codepath = 'wuzzy-nest.wuzzy-nest'

describe('WuzzyNest Searching', function()
  _G.send = spy.new(function() end)
  local match = require('luassert.match')
  local utils = require('.utils')
  local WuzzyNest = require(codepath)
  before_each(function()
    CacheOriginalGlobals()
    WuzzyNest = require(codepath)
  end)
  after_each(function()
    RestoreOriginalGlobals()
    package.loaded[codepath] = nil
  end)

  local function addDocument(url, contentType, content)
    local handler = GetHandler('Index-Document')
    handler.handle({
      id = 'message-id-1',
      from = _G.owner,
      target = 'wuzzy-nest-process-id',
      action = 'Index-Document',
      data = content,
      ['document-last-crawled-at'] = tostring(os.time()),
      ['document-url'] = url,
      ['document-content-type'] = contentType
    })
  end

  it('requires query', function()
    _G.send = spy.new(function() end)
    local handler = GetHandler('Search')

    assert.has_error(function()
      handler.handle({
        id = 'message-id-1',
        from = _G.owner,
        target = 'wuzzy-nest-process-id',
        action = 'Search'
      })
    end)
  end)

  it('handles simple search queries', function()
    _G.send = spy.new(function() end)
    local handler = GetHandler('Search')
    local memeticblockUrl = 'https://memeticblock.com'
    addDocument(
      memeticblockUrl,
      'text/html',
      'This is a test document from memeticblock, it says test twice'
    )
    local artbycityUrl = 'https://artby.city'
    addDocument(
      artbycityUrl,
      'text/html',
      'This is another test document from artbycity'
    )
    local wuzzyUrl = 'https://wuzzy.io'
    addDocument(
      wuzzyUrl,
      'text/html',
      'This is yet another test document from wuzzy'
    )

    _G.send:clear()
    handler.handle({
      id = 'message-id-1',
      from = _G.owner,
      target = 'wuzzy-nest-process-id',
      action = 'Search',
      query = 'memeticblock'
    })
    local function is_simple_search_1(state, args)
      return function(msg)
        local results = require('json').decode(msg.data)
        return msg.target == _G.owner and
          msg.action == 'Search-Result' and
          results.SearchType == 'simple' and
          results.TotalCount == 1 and
          #results.Hits == 1 and
          results.Hits[1].doc.DocumentId == memeticblockUrl and
          results.Hits[1].score == 1
      end
    end
    assert:register('matcher', 'simple_search_1', is_simple_search_1)
    assert.spy(_G.send).was.called_with(match.is_simple_search_1())

    _G.send:clear()
    handler.handle({
      id = 'message-id-2',
      from = _G.owner,
      target = 'wuzzy-nest-process-id',
      action = 'Search',
      query = 'another'
    })
    local function is_simple_search_2(state, args)
      return function (msg)
        local results = require('json').decode(msg.data)
        local artbycityHit = utils.find(
          function (hit) return hit.doc.DocumentId == artbycityUrl end,
          results.Hits
        )
        local wuzzyHit = utils.find(
          function (hit) return hit.doc.DocumentId == wuzzyUrl end,
          results.Hits
        )
        return msg.target == _G.owner and
          msg.action == 'Search-Result' and
          results.SearchType == 'simple' and
          results.TotalCount == 2 and
          #results.Hits == 2 and
          results.Hits[1].score == 1 and
          results.Hits[1].doc.DocumentId == artbycityUrl and
          results.Hits[2].score == 1 and
          results.Hits[2].doc.DocumentId == wuzzyUrl
      end
    end
    assert:register('matcher', 'simple_search_2', is_simple_search_2)
    assert.spy(_G.send).was.called_with(match.is_simple_search_2())

    _G.send:clear()
    handler.handle({
      id = 'message-id-3',
      from = _G.owner,
      target = 'wuzzy-nest-process-id',
      action = 'Search',
      query = 'nonexistent'
    })
    local function is_simple_search_3(state, args)
      return function(msg)
        local results = require('json').decode(msg.data)
        return msg.target == _G.owner and
          msg.action == 'Search-Result' and
          results.SearchType == 'simple' and
          results.TotalCount == 0 and
          #results.Hits == 0
      end
    end
    assert:register('matcher', 'simple_search_3', is_simple_search_3)
    assert.spy(_G.send).was.called_with(match.is_simple_search_3())

    _G.send:clear()
    handler.handle({
      id = 'message-id-4',
      from = _G.owner,
      target = 'wuzzy-nest-process-id',
      action = 'Search',
      query = 'test'
    })
    local function is_simple_search_4(state, args)
      return function(msg)
        local results = require('json').decode(msg.data)
        return msg.target == _G.owner and
          msg.action == 'Search-Result' and
          results.SearchType == 'simple' and
          results.TotalCount == 3 and
          #results.Hits == 3 and
          results.Hits[1].score == 2 and
          results.Hits[1].doc.DocumentId == memeticblockUrl and
          results.Hits[2].score == 1 and
          results.Hits[2].doc.DocumentId == artbycityUrl and
          results.Hits[3].score == 1 and
          results.Hits[3].doc.DocumentId == wuzzyUrl
      end
    end
    assert:register('matcher', 'simple_search_4', is_simple_search_4)
    assert.spy(_G.send).was.called_with(match.is_simple_search_4())
  end)

  it('handles bm25 search queries', function()
    _G.send = spy.new(function() end)
    local handler = GetHandler('Search')
    local wuzzyUrl1 = 'https://wuzzy.io/doc1'
    addDocument(wuzzyUrl1, 'text/plain', 'Wuzzy')
    local wuzzyUrl2 = 'https://wuzzy.io/doc2'
    addDocument(wuzzyUrl2, 'text/plain', 'Wuzzy S')
    local wuzzyUrl3 = 'https://wuzzy.io/doc3'
    addDocument(wuzzyUrl3, 'text/plain', 'Wuzzy AO Search')
    local wuzzyUrl4 = 'https://wuzzy.io/doc4'
    addDocument(wuzzyUrl4, 'text/plain', 'Wuzzy Search')
    local wuzzyUrl5 = 'https://wuzzy.io/doc5'
    addDocument(wuzzyUrl5, 'text/plain', 'Wuzzy Wuzzy Search Search')
    local wuzzyUrl6 = 'https://wuzzy.io/doc6'
    addDocument(
      wuzzyUrl6,
      'text/plain',
      'Wuzzy Wuzzy Wuzzy Search Search Search'
    )

    _G.send:clear()
    handler.handle({
      id = 'message-id-1',
      from = _G.owner,
      target = 'wuzzy-nest-process-id',
      action = 'Search',
      query = 'Wuzzy',
      ['search-type'] = 'bm25'
    })
    local function is_bm25_search_1(state, args)
      return function(msg)
        local results = require('json').decode(msg.data)
        return msg.target == _G.owner and
          msg.action == 'Search-Result' and
          results.SearchType == 'bm25' and
          results.TotalCount == 6 and
          #results.Hits == 6 and
          results.Hits[1].doc.DocumentId == wuzzyUrl1 and
          results.Hits[1].score > 0.1 and  -- score = 0.10419692325373
          results.Hits[1].count == 1 and
          results.Hits[2].doc.DocumentId == wuzzyUrl2 and
          results.Hits[2].score > 0.09 and -- score = 0.097592892906662
          results.Hits[2].count == 1 and
          results.Hits[3].doc.DocumentId == wuzzyUrl6 and
          results.Hits[3].score > 0.08 and -- score = 0.092081001945156
          results.Hits[3].count == 3 and
          results.Hits[4].doc.DocumentId == wuzzyUrl5 and
          results.Hits[4].score > 0.08 and -- score = 0.089988251900948
          results.Hits[4].count == 2 and
          results.Hits[5].doc.DocumentId == wuzzyUrl4 and
          results.Hits[5].score > 0.07 and -- score = 0.084244320928547
          results.Hits[5].count == 1 and
          results.Hits[6].doc.DocumentId == wuzzyUrl3 and
          results.Hits[6].score > 0.07 and -- score = 0.077855004453629
          results.Hits[6].count == 1
      end
    end
    assert:register('matcher', 'bm25_search_1', is_bm25_search_1)
    assert.spy(_G.send).was.called_with(match.is_bm25_search_1())
  end)
end)
