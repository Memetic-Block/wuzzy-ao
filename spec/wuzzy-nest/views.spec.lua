local codepath = 'wuzzy-nest.wuzzy-nest'

describe('WuzzyNest Views', function ()
  _G.send = spy.new(function() end)
  require(codepath)
  require('views.wuzzy-nest')
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

  it('simple search', function()
    addDocument(
      'https://memeticblock.com',
      'text/html',
      _G.MemeticBlockIndexContent
    )
    addDocument(
      'https://memeticblock.com/about',
      'text/html',
      _G.MemeticBlockAboutContent
    )

    local results = search_simple(
      { WuzzyNest = WuzzyNest },
      { query = 'memetic' }
    )
    print('results', require('json').encode(results))
  end)

  it('bm25 search', function()
    addDocument(
      'https://memeticblock.com',
      'text/html',
      _G.MemeticBlockIndexContent
    )
    addDocument(
      'https://memeticblock.com/about',
      'text/html',
      _G.MemeticBlockAboutContent
    )

    local results = search_bm25(
      { WuzzyNest = WuzzyNest },
      { query = 'memetic' }
    )
    -- print('results', require('json').encode(results))
    print('total hits', results['total_hits'])
    print('hit 1 id', results['1_docid'])
    print('hit 1 content', results['1_content'])
    print('hit 2 id', results['2_docid'])
    print('hit 2 content', results['2_content'])
  end)

  it('paging functionality', function()
    addDocument(
      'https://memeticblock.com',
      'text/html',
      _G.MemeticBlockIndexContent
    )
    addDocument(
      'https://memeticblock.com/about',
      'text/html',
      _G.MemeticBlockAboutContent
    )

    -- Test with page size of 1 to force pagination
    local page1Results = search_simple(
      { WuzzyNest = WuzzyNest },
      { query = 'memetic', page = 1, page_size = 1 }
    )

    local page2Results = search_simple(
      { WuzzyNest = WuzzyNest },
      { query = 'memetic', page = 2, page_size = 1 }
    )

    print('Page 1 - Total hits:', page1Results['total_hits'])
    print('Page 1 - Page:', page1Results['page'])
    print('Page 1 - Page size:', page1Results['page_size'])
    print('Page 1 - Total pages:', page1Results['total_pages'])
    print('Page 1 - Has next:', page1Results['has_next_page'])
    print('Page 1 - Has previous:', page1Results['has_previous_page'])
    print('Page 1 - Result count:', page1Results['1_docid'] and 1 or 0)

    print('Page 2 - Page:', page2Results['page'])
    print('Page 2 - Has next:', page2Results['has_next_page'])
    print('Page 2 - Has previous:', page2Results['has_previous_page'])
    print('Page 2 - Result count:', page2Results['1_docid'] and 1 or 0)
  end)

  it('bm25 search with no matches', function()
    addDocument(
      'https://memeticblock.com',
      'text/html',
      _G.MemeticBlockIndexContent
    )
    addDocument(
      'https://memeticblock.com/about',
      'text/html',
      _G.MemeticBlockAboutContent
    )

    local results = search_bm25(
      { WuzzyNest = WuzzyNest },
      { query = 'arweave' }
    )
    print('results', require('json').encode(results))
    -- print('total hits', results['total_hits'])
    -- print('hit 1 id', results['1_docid'])
    -- print('hit 1 content', results['1_content'])
    -- print('hit 2 id', results['2_docid'])
    -- print('hit 2 content', results['2_content'])
  end)

  it('unicode search', function()
    -- Test with Japanese text to ensure UTF-8 characters are preserved
    addDocument(
      'https://example.com/japanese',
      'text/html',
      'これは日本語のテストです。日本語の文字が正しく処理されることを確認します。'
    )
    addDocument(
      'https://example.com/mixed',
      'text/html',
      'Mixed content with 日本語 and English text together.'
    )

    local results = search_simple(
      { WuzzyNest = WuzzyNest },
      { query = '日本語' }
    )
    
    print('Unicode search results:', require('json').encode(results))
    
    -- Verify that we found matches and the content is not corrupted
    assert(results['total_hits'] > 0, 'Should find matches for Japanese text')
    
    -- Check that the content contains the original Japanese characters
    local content1 = results['1_content'] or ''
    local content2 = results['2_content'] or ''
    local combinedContent = content1 .. content2
    
    assert(string.find(combinedContent, '日本語'), 'Content should contain original Japanese characters')
    assert(not string.find(combinedContent, 'æœ¬èªž'), 'Content should not contain corrupted characters')
  end)
end)