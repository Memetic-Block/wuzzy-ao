local codepath = 'wuzzy-crawler.wuzzy-crawler'

describe('Wuzzy-Crawler Crawl-Tasks', function()
  local WuzzyCrawler = require(codepath)
  before_each(function()
    CacheOriginalGlobals()
    WuzzyCrawler = require(codepath)
  end)
  after_each(function()
    RestoreOriginalGlobals()
    package.loaded[codepath] = nil
    package.loaded['..common.acl'] = nil
  end)

  describe('Add-Crawl-Tasks', function()
    it('rejects Add-Crawl-Tasks messages from unknown callers', function()
      _G.send = spy.new(function() end)

      assert.has_error(function()
        GetHandler('Add-Crawl-Tasks').handle({
          from = 'alice-address',
          data = 'mock-crawl-task'
        })
      end, 'Permission Denied')
    end)

    it('requires Crawl Task Data', function()
      _G.send = spy.new(function() end)

      assert.has_error(function()
        GetHandler('Add-Crawl-Tasks').handle({ from = _G.owner })
      end, 'Missing Crawl Task Data')
    end)

    it('validates Add-Crawl-Tasks Task Data', function()
      _G.send = spy.new(function() end)
      local crawlTaskData = 'invalid-url'

      assert.has_error(function()
        GetHandler('Add-Crawl-Tasks').handle({
          from = _G.owner,
          data = crawlTaskData
        })
      end, 'Invalid Crawl Task Data: ' .. crawlTaskData)
    end)

    it('rejects duplicate crawl tasks', function()
      _G.send = spy.new(function() end)
      local url = 'https://example.com/some/path'

      GetHandler('Add-Crawl-Tasks').handle({
        from = _G.owner,
        data = url
      })

      assert.has_error(function()
        GetHandler('Add-Crawl-Tasks').handle({
          from = _G.owner,
          data = url
        })
      end, 'Duplicate Crawl Task: ' .. url)
    end)

    it('accepts Add-Crawl-Tasks message from owner, admin, acl', function()
      _G.send = spy.new(function() end)
      local aliceAddress = 'alice-address'
      local bobAddress = 'bob-address'
      GetHandler('Update-Roles').handle({
        from = _G.owner,
        data = require('json').encode({
          Grant = {
            [aliceAddress] = { 'admin' },
            [bobAddress] = { 'Add-Crawl-Tasks' }
          }
        })
      })
      _G.send:clear()
      local tasks = {
        'arns://memeticblock',
        'arns://wuzzy',
        'arns://cookbook',
        'arns://cookbook_ao'
      }

      GetHandler('Add-Crawl-Tasks').handle({
        from = _G.owner,
        data = tasks[1] .. '\n' .. tasks[2]
      })
      assert.spy(_G.send).was.called_with({
        target = _G.owner,
        action = 'Add-Crawl-Tasks-Result',
        data = 'OK'
      })

      GetHandler('Add-Crawl-Tasks').handle({
        from = aliceAddress,
        data = tasks[3]
      })
      assert.spy(_G.send).was.called_with({
        target = _G.owner,
        action = 'Add-Crawl-Tasks-Result',
        data = 'OK'
      })

      GetHandler('Add-Crawl-Tasks').handle({
        from = bobAddress,
        data = tasks[4]
      })
      assert.spy(_G.send).was.called_with({
        target = _G.owner,
        action = 'Add-Crawl-Tasks-Result',
        data = 'OK'
      })

      assert.are_same({
        [tasks[1]] = {
          AddedBy = _G.owner,
          SubmittedUrl = tasks[1],
          URL = tasks[1],
          Protocol = 'arns',
          Domain = 'memeticblock',
          Path = ''
        },
        [tasks[2]] = {
          AddedBy = _G.owner,
          SubmittedUrl = tasks[2],
          URL = tasks[2],
          Protocol = 'arns',
          Domain = 'wuzzy',
          Path = ''
        },
        [tasks[3]] = {
          AddedBy = aliceAddress,
          SubmittedUrl = tasks[3],
          URL = tasks[3],
          Protocol = 'arns',
          Domain = 'cookbook',
          Path = ''
        },
        [tasks[4]] = {
          AddedBy = bobAddress,
          SubmittedUrl = tasks[4],
          URL = tasks[4],
          Protocol = 'arns',
          Domain = 'cookbook_ao',
          Path = ''
        }
      }, WuzzyCrawler.State.CrawlTasks)
    end)

    pending('uses ~patch@1.0 whenever updating state')
  end)

  describe('Remove-Crawl-Tasks', function()
    it('rejects Remove-Crawl-Tasks message from unknown callers', function()
      _G.send = spy.new(function() end)

      assert.has_error(function()
        GetHandler('Remove-Crawl-Tasks').handle({
          from = 'alice-address',
          data = 'mock-crawl-task'
        })
      end, 'Permission Denied')
    end)

    it('requires Remove-Crawl-Tasks Task Data', function()
      _G.send = spy.new(function() end)

      assert.has_error(function()
        GetHandler('Remove-Crawl-Tasks').handle({ from = _G.owner })
      end, 'Missing Crawl Task Data to remove')
    end)

    it('validates Remove-Crawl-Tasks Task Data', function()
      local url = 'arns://memeticblock'

      assert.has_error(function()
        GetHandler('Remove-Crawl-Tasks').handle({
          from = _G.owner,
          data = url
        })
      end, 'Crawl Task not found: ' .. url)
    end)

    it('accepts Remove-Crawl-Tasks message from owner, admin, acl', function()
      _G.send = spy.new(function() end)
      local aliceAddress = 'alice-address'
      local bobAddress = 'bob-address'
      GetHandler('Update-Roles').handle({
        from = _G.owner,
        data = require('json').encode({
          Grant = {
            [aliceAddress] = { 'admin' },
            [bobAddress] = { 'Remove-Crawl-Tasks' }
          }
        })
      })
      _G.send:clear()
      local tasks = {
        'arns://memeticblock',
        'arns://wuzzy',
        'arns://cookbook',
        'arns://cookbook_ao'
      }

      GetHandler('Add-Crawl-Tasks').handle({
        from = _G.owner,
        data = tasks[1] .. '\n' ..
          tasks[2] .. '\n' ..
          tasks[3] .. '\n' ..
          tasks[4]
      })
      assert.is_not_nil(WuzzyCrawler.State.CrawlTasks[tasks[1]])
      assert.is_not_nil(WuzzyCrawler.State.CrawlTasks[tasks[2]])
      assert.is_not_nil(WuzzyCrawler.State.CrawlTasks[tasks[3]])
      assert.is_not_nil(WuzzyCrawler.State.CrawlTasks[tasks[4]])

      GetHandler('Remove-Crawl-Tasks').handle({
        from = _G.owner,
        data = tasks[2]
      })
      assert.is_nil(WuzzyCrawler.State.CrawlTasks[tasks[2]])

      GetHandler('Remove-Crawl-Tasks').handle({
        from = aliceAddress,
        data = tasks[3]
      })
      assert.is_nil(WuzzyCrawler.State.CrawlTasks[tasks[3]])

      GetHandler('Remove-Crawl-Tasks').handle({
        from = bobAddress,
        data = tasks[1]
      })
      assert.is_nil(WuzzyCrawler.State.CrawlTasks[tasks[1]])

      assert.are_same({
        [tasks[4]] = {
          AddedBy = _G.owner,
          SubmittedUrl = tasks[4],
          URL = tasks[4],
          Protocol = 'arns',
          Domain = 'cookbook_ao',
          Path = ''
        }
      }, WuzzyCrawler.State.CrawlTasks)
    end)

    pending('uses ~patch@1.0 whenever updating state')
  end)
end)
