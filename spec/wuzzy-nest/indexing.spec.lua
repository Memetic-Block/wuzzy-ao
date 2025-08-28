local codepath = 'wuzzy-nest.wuzzy-nest'

describe('WuzzyNest Indexing', function()
  _G.send = spy.new(function() end)
  require(codepath)
  before_each(function()
    CacheOriginalGlobals()
    require(codepath)
  end)
  after_each(function()
    RestoreOriginalGlobals()
    package.loaded[codepath] = nil
  end)

  describe('Accepting Documents', function()
    it('accepts Index-Document messages & tracks Document stats', function()
      _G.send = spy.new(function() end)
      local handler = GetHandler('Index-Document')
      local now = os.time()
      local from = _G.owner
      local protocol1 = 'https'
      local domain1 = 'arweave.net'
      local path1 = '/info'
      local protocol2 = 'https'
      local domain2 = 'frostor.xyz'
      local path2 = '/info'
      local documents = {
        {
          LastCrawledAt = tostring(now),
          URL = protocol1 .. '://' .. domain1 .. path1,
          ContentType = 'text/html',
          Content = 'This is a test document.',
          Title = 'Test Document 1 Title',
          Description = 'Test Document 1 Description'
        },
        {
          LastCrawledAt = tostring(now),
          URL = protocol2 .. '://' .. domain2 .. path2,
          ContentType = 'text/html',
          Content = 'This is a test document.'
        }
      }

      handler.handle({
        id = 'mock-message-id-1',
        from = from,
        target = 'wuzzy-nest-process-id',
        action = 'Index-Document',
        data = documents[1].Content,
        ['document-last-crawled-at'] = documents[1].LastCrawledAt,
        ['document-url'] = documents[1].URL,
        ['document-content-type'] = documents[1].ContentType,
        ['document-title'] = documents[1].Title,
        ['document-description'] = documents[1].Description
      })
      handler.handle({
        id = 'mock-message-id-2',
        from = from,
        target = 'wuzzy-nest-process-id',
        action = 'Index-Document',
        data = documents[2].Content,
        ['document-last-crawled-at'] = documents[2].LastCrawledAt,
        ['document-url'] = documents[2].URL,
        ['document-content-type'] = documents[2].ContentType,
        ['document-title'] = documents[2].Title,
        ['document-description'] = documents[2].Description
      })

      assert.spy(_G.send).was.called_with({
        target = from,
        action = 'Index-Document-Result',
        data = 'OK',
        ['document-id'] = documents[1].URL
      })
      assert.spy(_G.send).was.called_with({
        target = from,
        action = 'Index-Document-Result',
        data = 'OK',
        ['document-id'] = documents[2].URL
      })
      assert(WuzzyNest.State.Documents[1].DocumentId == documents[1].URL)
      assert(WuzzyNest.State.Documents[2].DocumentId == documents[2].URL)
      assert.are_same({
        SubmittedBy = from,
        DocumentId = documents[1].URL,
        LastCrawledAt = tonumber(documents[1].LastCrawledAt),
        Protocol = protocol1,
        Domain = domain1,
        Path = path1,
        URL = documents[1].URL,
        ContentType = documents[1].ContentType,
        Content = documents[1].Content,
        TermCount = #documents[1].Content,
        Title = documents[1].Title,
        Description = documents[1].Description
      }, WuzzyNest.State.Documents[1])
      assert.are_same({
        SubmittedBy = from,
        DocumentId = documents[2].URL,
        LastCrawledAt = tonumber(documents[2].LastCrawledAt),
        Protocol = protocol2,
        Domain = domain2,
        Path = path2,
        URL = documents[2].URL,
        ContentType = documents[2].ContentType,
        Content = documents[2].Content,
        TermCount = #documents[2].Content
      }, WuzzyNest.State.Documents[2])

      assert(WuzzyNest.State.TotalDocuments == #documents)
      assert(
        WuzzyNest.State.TotalTermCount ==
          #documents[1].Content + #documents[2].Content
      )
      assert(
        WuzzyNest.State.AverageDocumentTermLength ==
          (#documents[1].Content + #documents[2].Content) / #documents
      )
    end)

    it('ignores Index messages from unknown sources', function()
      _G.send = spy.new(function() end)
      local handler = GetHandler('Index-Document')

      assert.has_error(function()
        handler.handle({
          id = 'message-id-1',
          from = 'unknown-address',
          target = 'wuzzy-nest-process-id',
          action = 'Index-Document',
          data = 'Test document content',
          ['document-last-crawled-at'] = tostring(os.time()),
          ['document-url'] = 'http://example.com/test',
          ['document-content-type'] = 'text/html'
        })
      end, 'Permission Denied')
    end)

    it('normalizes document-id to scheme://domain/path', function()
      _G.send = spy.new(function() end)
      local handler = GetHandler('Index-Document')
      local baseUrl = 'http://www.example.com/info/path'
      local url = baseUrl .. '/back/../?json=true&skip=100#middle-part'

      handler.handle({
        id = 'mock-message-id-1',
        from = _G.owner,
        target = 'wuzzy-nest-process-id',
        action = 'Index-Document',
        data = 'This is a test document',
        ['document-last-crawled-at'] = tostring(os.time()),
        ['document-url'] = url,
        ['document-content-type'] = 'text/html'
      })

      assert(WuzzyNest.State.Documents[1].DocumentId == baseUrl)
    end)
  end)

  describe('Validation', function()
    it('requires document-last-crawled-at', function()
      _G.send = spy.new(function() end)
      local handler = GetHandler('Index-Document')

      assert.has_error(function()
        handler.handle({
          id = 'message-id-1',
          from = _G.owner,
          target = 'wuzzy-nest-process-id',
          action = 'Index-Document',
          data = 'Test document content',
          ['document-url'] = 'http://example.com/test',
          ['document-content-type'] = 'text/html'
        })
      end, 'Missing document-last-crawled-at')
    end)

    it('validates document-last-crawled-at', function()
      _G.send = spy.new(function() end)
      local handler = GetHandler('Index-Document')
      local now = 'yesterday'

      assert.has_error(function()
        handler.handle({
          id = 'message-id-1',
          from = _G.owner,
          target = 'wuzzy-nest-process-id',
          action = 'Index-Document',
          data = 'Test document content',
          ['document-last-crawled-at'] = now,
          ['document-url'] = 'http://example.com/test',
          ['document-content-type'] = 'text/html'
        })
      end, 'Invalid document-last-crawled-at: ' .. now)
    end)

    it('requires document-url', function()
      _G.send = spy.new(function() end)
      local handler = GetHandler('Index-Document')

      assert.has_error(function()
        handler.handle({
          id = 'message-id-1',
          from = _G.owner,
          target = 'wuzzy-nest-process-id',
          action = 'Index-Document',
          data = 'Test document content',
          ['document-last-crawled-at'] = tostring(os.time()),
          -- ['document-url'] = 'http://example.com/test',
          ['document-content-type'] = 'text/html'
        })
      end, 'Missing document-url')
    end)

    it('validates document-url', function()
      _G.send = spy.new(function() end)
      local handler = GetHandler('Index-Document')
      local url = 'invalid-url'

      assert.has_error(function()
        handler.handle({
          id = 'message-id-1',
          from = _G.owner,
          target = 'wuzzy-nest-process-id',
          action = 'Index-Document',
          data = 'Test document content',
          ['document-last-crawled-at'] = tostring(os.time()),
          ['document-url'] = url,
          ['document-content-type'] = 'text/html'
        })
      end, 'Invalid document-url: ' .. url)
    end)

    it('requires document-content-type', function()
      _G.send = spy.new(function() end)
      local handler = GetHandler('Index-Document')

      assert.has_error(function()
        handler.handle({
          id = 'message-id-1',
          from = _G.owner,
          target = 'wuzzy-nest-process-id',
          action = 'Index-Document',
          data = 'Test document content',
          ['document-last-crawled-at'] = tostring(os.time()),
          ['document-url'] = 'https://arweave.net'
        })
      end, 'Missing document-content-type')
    end)

    it('validates document-content-type', function()
      _G.send = spy.new(function() end)
      local handler = GetHandler('Index-Document')
      local contentType = 'text/wuzzy'

      assert.has_error(function()
        handler.handle({
          id = 'message-id-1',
          from = _G.owner,
          target = 'wuzzy-nest-process-id',
          action = 'Index-Document',
          data = 'Test document content',
          ['document-last-crawled-at'] = tostring(os.time()),
          ['document-url'] = 'https://arweave.net',
          ['document-content-type'] = contentType
        })
      end, 'Invalid document-content-type: ' .. contentType)
    end)

    it('requires document content in message data', function()
      _G.send = spy.new(function() end)
      local handler = GetHandler('Index-Document')

      assert.has_error(function()
        handler.handle({
          id = 'message-id-1',
          from = _G.owner,
          target = 'wuzzy-nest-process-id',
          action = 'Index-Document',
          ['document-last-crawled-at'] = tostring(os.time()),
          ['document-url'] = 'https://arweave.net',
          ['document-content-type'] = 'text/html'
        })
      end, 'Missing Document Content')
    end)
  end)

  describe('Removing Documents', function()
    it('requires document-id to remove a Document', function()
      _G.send = spy.new(function() end)
      local handler = GetHandler('Remove-Document')

      assert.has_error(function()
        handler.handle({
          id = 'message-id-1',
          from = _G.owner,
          target = 'wuzzy-nest-process-id',
          action = 'Remove-Document'
        })
      end, 'document-id is required')
    end)

    it('throws if document does not exist', function()
      _G.send = spy.new(function() end)
      local handler = GetHandler('Remove-Document')

      assert.has_error(function()
        handler.handle({
          id = 'message-id-1',
          from = _G.owner,
          target = 'wuzzy-nest-process-id',
          action = 'Remove-Document',
          ['document-id'] = 'non-existent-doc-id'
        })
      end, 'Document not found')
    end)

    it('prevents unknown callers from removing Documents', function()
      _G.send = spy.new(function() end)
      local handler = GetHandler('Remove-Document')

      assert.has_error(function()
        handler.handle({
          id = 'message-id-1',
          from = 'unknown-user',
          target = 'wuzzy-nest-process-id',
          action = 'Remove-Document',
          ['document-id'] = 'test-document-id'
        })
      end, 'Permission Denied')
    end)

    it('allows owner, admin, or ACL to remove Documents', function()
      local url = 'https://arweave.net'
      _G.send = spy.new(function() end)
      GetHandler('Index-Document').handle({
        id = 'message-id-1',
        from = _G.owner,
        target = 'wuzzy-nest-process-id',
        action = 'Index-Document',
        data = 'Test document content',
        ['document-last-crawled-at'] = tostring(os.time()),
        ['document-url'] = url,
        ['document-content-type'] = 'text/html'
      })

      _G.send = spy.new(function() end)
      local handler = GetHandler('Remove-Document')

      handler.handle({
        id = 'message-id-2',
        from = _G.owner,
        target = 'wuzzy-nest-process-id',
        action = 'Remove-Document',
        ['document-id'] = url
      })

      assert.spy(_G.send).was.called_with({
        target = _G.owner,
        action = 'Remove-Document-Result',
        data = 'OK',
        ['document-id'] = url
      })
      assert.is_nil(WuzzyNest.State.Documents[url])
    end)
  end)

  describe('Updating Documents', function()
    it('allows updating existing Documents by URL & updates stats', function()
      local url = 'https://arweave.net'
      _G.send = spy.new(function() end)
      local handler = GetHandler('Index-Document')
      local initialContent = 'Test document content'
      local newContent = 'This is updated document content'
      local earlier = tostring(os.time() - 3600)
      local now = tostring(os.time())

      handler.handle({
        id = 'message-id-1',
        from = _G.owner,
        target = 'wuzzy-nest-process-id',
        action = 'Index-Document',
        data = initialContent,
        ['document-last-crawled-at'] = earlier,
        ['document-url'] = url,
        ['document-content-type'] = 'text/html'
      })

      handler.handle({
        id = 'message-id-2',
        from = _G.owner,
        target = 'wuzzy-nest-process-id',
        action = 'Index-Document',
        data = newContent,
        ['document-last-crawled-at'] = now,
        ['document-url'] = url,
        ['document-content-type'] = 'text/html'
      })

      assert(WuzzyNest.State.Documents[1].LastCrawledAt == tonumber(now))
      assert(WuzzyNest.State.Documents[1].Content == newContent)
      assert(WuzzyNest.State.Documents[1].TermCount == #newContent)
      assert(WuzzyNest.State.TotalDocuments == 1)
      assert(WuzzyNest.State.TotalTermCount == #newContent)
      assert(WuzzyNest.State.AverageDocumentTermLength == #newContent)
    end)
  end)
end)
