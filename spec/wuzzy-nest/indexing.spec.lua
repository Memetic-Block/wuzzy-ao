local codepath = 'wuzzy-nest.wuzzy-nest'

describe('Wuzzy-Nest Indexing', function()
  local WuzzyNest = require(codepath)
  before_each(function()
    CacheOriginalGlobals()
    WuzzyNest = require(codepath)
  end)
  after_each(function()
    RestoreOriginalGlobals()
    package.loaded[codepath] = nil
  end)

  pending('uses ~patch@1.0 whenever updating state', function() end)

  describe('Accepting Documents', function()
    pending('Document Titles', function() end)
    pending('Document Descriptions', function() end)
    pending('Document Links', function() end)

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
          Content = 'This is a test document.'
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
        ['Document-Last-Crawled-At'] = documents[1].LastCrawledAt,
        ['Document-URL'] = documents[1].URL,
        ['Document-Content-Type'] = documents[1].ContentType
      })
      handler.handle({
        id = 'mock-message-id-2',
        from = from,
        target = 'wuzzy-nest-process-id',
        action = 'Index-Document',
        data = documents[2].Content,
        ['Document-Last-Crawled-At'] = documents[2].LastCrawledAt,
        ['Document-URL'] = documents[2].URL,
        ['Document-Content-Type'] = documents[2].ContentType
      })

      assert.spy(_G.send).was.called_with({
        target = from,
        action = 'Index-Document-Result',
        data = 'OK',
        ['Document-Id'] = documents[1].URL
      })
      assert.spy(_G.send).was.called_with({
        target = from,
        action = 'Index-Document-Result',
        data = 'OK',
        ['Document-Id'] = documents[2].URL
      })
      assert.is_not_nil(WuzzyNest.State.Documents[documents[1].URL])
      assert.is_not_nil(WuzzyNest.State.Documents[documents[2].URL])
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
        TermCount = #documents[1].Content
      }, WuzzyNest.State.Documents[documents[1].URL])
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
      }, WuzzyNest.State.Documents[documents[2].URL])

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
          ['Document-Last-Crawled-At'] = tostring(os.time()),
          ['Document-URL'] = 'http://example.com/test',
          ['Document-Content-Type'] = 'text/html'
        })
      end, 'Permission Denied')
    end)

    it('normalizes Document-Id to scheme://domain/path', function()
      _G.send = spy.new(function() end)
      local handler = GetHandler('Index-Document')
      local baseUrl = 'http://www.example.com/info/path'
      local url = baseUrl .. '?json=true&skip=100#middle-part'

      handler.handle({
        id = 'mock-message-id-1',
        from = _G.owner,
        target = 'wuzzy-nest-process-id',
        action = 'Index-Document',
        data = 'This is a test document',
        ['Document-Last-Crawled-At'] = tostring(os.time()),
        ['Document-URL'] = url,
        ['Document-Content-Type'] = 'text/html'
      })

      assert.is_not_nil(WuzzyNest.State.Documents[baseUrl])
    end)
  end)

  describe('Validation', function()
    it('requires Document-Last-Crawled-At', function()
      _G.send = spy.new(function() end)
      local handler = GetHandler('Index-Document')

      assert.has_error(function()
        handler.handle({
          id = 'message-id-1',
          from = _G.owner,
          target = 'wuzzy-nest-process-id',
          action = 'Index-Document',
          data = 'Test document content',
          ['Document-URL'] = 'http://example.com/test',
          ['Document-Content-Type'] = 'text/html'
        })
      end, 'Missing Document-Last-Crawled-At')
    end)

    it('validates Document-Last-Crawled-At', function()
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
          ['Document-Last-Crawled-At'] = now,
          ['Document-URL'] = 'http://example.com/test',
          ['Document-Content-Type'] = 'text/html'
        })
      end, 'Invalid Document-Last-Crawled-At: ' .. now)
    end)

    it('requires Document-URL', function()
      _G.send = spy.new(function() end)
      local handler = GetHandler('Index-Document')

      assert.has_error(function()
        handler.handle({
          id = 'message-id-1',
          from = _G.owner,
          target = 'wuzzy-nest-process-id',
          action = 'Index-Document',
          data = 'Test document content',
          ['Document-Last-Crawled-At'] = tostring(os.time()),
          -- ['Document-URL'] = 'http://example.com/test',
          ['Document-Content-Type'] = 'text/html'
        })
      end, 'Missing Document-URL')
    end)

    it('validates Document-URL', function()
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
          ['Document-Last-Crawled-At'] = tostring(os.time()),
          ['Document-URL'] = url,
          ['Document-Content-Type'] = 'text/html'
        })
      end, 'Invalid Document-URL: ' .. url)
    end)

    it('requires Document-Content-Type', function()
      _G.send = spy.new(function() end)
      local handler = GetHandler('Index-Document')

      assert.has_error(function()
        handler.handle({
          id = 'message-id-1',
          from = _G.owner,
          target = 'wuzzy-nest-process-id',
          action = 'Index-Document',
          data = 'Test document content',
          ['Document-Last-Crawled-At'] = tostring(os.time()),
          ['Document-URL'] = 'https://arweave.net'
        })
      end, 'Missing Document-Content-Type')
    end)

    it('validates Document-Content-Type', function()
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
          ['Document-Last-Crawled-At'] = tostring(os.time()),
          ['Document-URL'] = 'https://arweave.net',
          ['Document-Content-Type'] = contentType
        })
      end, 'Invalid Document-Content-Type: ' .. contentType)
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
          ['Document-Last-Crawled-At'] = tostring(os.time()),
          ['Document-URL'] = 'https://arweave.net',
          ['Document-Content-Type'] = 'text/html'
        })
      end, 'Missing Document Content')
    end)
  end)

  describe('Removing Documents', function()
    it('requires Document-Id to remove a Document', function()
      _G.send = spy.new(function() end)
      local handler = GetHandler('Remove-Document')

      assert.has_error(function()
        handler.handle({
          id = 'message-id-1',
          from = _G.owner,
          target = 'wuzzy-nest-process-id',
          action = 'Remove-Document'
        })
      end, 'Document-Id is required')
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
          ['Document-Id'] = 'non-existent-doc-id'
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
          ['Document-Id'] = 'test-document-id'
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
        ['Document-Last-Crawled-At'] = tostring(os.time()),
        ['Document-URL'] = url,
        ['Document-Content-Type'] = 'text/html'
      })

      _G.send = spy.new(function() end)
      local handler = GetHandler('Remove-Document')

      handler.handle({
        id = 'message-id-2',
        from = _G.owner,
        target = 'wuzzy-nest-process-id',
        action = 'Remove-Document',
        ['Document-Id'] = url
      })

      assert.spy(_G.send).was.called_with({
        target = _G.owner,
        action = 'Remove-Document-Result',
        data = 'OK',
        ['Document-Id'] = url
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
        ['Document-Last-Crawled-At'] = earlier,
        ['Document-URL'] = url,
        ['Document-Content-Type'] = 'text/html'
      })

      handler.handle({
        id = 'message-id-2',
        from = _G.owner,
        target = 'wuzzy-nest-process-id',
        action = 'Index-Document',
        data = newContent,
        ['Document-Last-Crawled-At'] = now,
        ['Document-URL'] = url,
        ['Document-Content-Type'] = 'text/html'
      })

      assert(WuzzyNest.State.Documents[url].LastCrawledAt == tonumber(now))
      assert(WuzzyNest.State.Documents[url].Content == newContent)
      assert(WuzzyNest.State.Documents[url].TermCount == #newContent)
      assert(WuzzyNest.State.TotalDocuments == 1)
      assert(WuzzyNest.State.TotalTermCount == #newContent)
      assert(WuzzyNest.State.AverageDocumentTermLength == #newContent)
    end)
  end)
end)
