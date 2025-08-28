local codepath = 'wuzzy-nest-registry.wuzzy-nest-registry'
local json = require('json')

describe('WuzzyNestRegistry Registration', function()
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
    _G.send:clear()
    package.loaded[codepath] = nil
  end)

  describe('Register', function()
    it('should register a new nest with valid owner and ACL', function()
      local nestId = 'nest123'
      local owner = 'owner123'
      local acl = {
        ['admin123'] = { admin = true },
        ['user123'] = { ['Index-Document'] = true }
      }
      local msg = {
        from = nestId,
        ['nest-owner'] = owner,
        data = json.encode(acl)
      }

      _G.send:clear()
      GetHandler('Register').handle(msg)

      assert.are.equal(owner, WuzzyNestRegistry.State.Nests[nestId].Owner)
      assert.same(acl, WuzzyNestRegistry.State.Nests[nestId].ACL)
      assert.spy(_G.send).was.called(1)
      assert.spy(_G.send).was.called_with({
        target = nestId,
        action = 'Register-Result',
        data = 'OK'
      })
    end)

    it('should not register if already registered', function()
      local nestId = 'nest123'
      WuzzyNestRegistry.State.Nests[nestId] = { Owner = 'old_owner', ACL = {} }
      local msg = {
        from = nestId,
        ['nest-owner'] = 'new_owner',
        data = json.encode({})
      }

      _G.send:clear()
      assert.has_error(function()
        GetHandler('Register').handle(msg)
      end, 'Already Registered')
    end)

    it('should error if missing Owner', function()
      local msg = {
        from = 'nest123',
        data = json.encode({})
      }

      assert.has_error(function()
        GetHandler('Register').handle(msg)
      end, 'Missing or invalid Owner')
    end)

    it('should error if invalid ACL data', function()
      local msg = {
        from = 'nest123',
        ['nest-owner'] = 'owner123',
        data = 'invalid json'
      }

      assert.has_error(function()
        GetHandler('Register').handle(msg)
      end, 'Invalid ACL data')
    end)

    it('should error if missing ACL data', function()
      local msg = {
        from = 'nest123',
        ['nest-owner'] = 'owner123'
      }

      assert.has_error(function()
        GetHandler('Register').handle(msg)
      end, 'Missing ACL data')
    end)
  end)

  describe('Unregister', function()
    it('should unregister an existing nest', function()
      local nestId = 'nest123'
      WuzzyNestRegistry.State.Nests[nestId] = { Owner = 'owner123', ACL = {} }
      local msg = {
        from = nestId
      }
      _G.send:clear()
      GetHandler('Unregister').handle(msg)

      assert.is_nil(WuzzyNestRegistry.State.Nests[nestId])
      assert.spy(_G.send).was.called(1)
      assert.spy(_G.send).was.called_with({
        target = nestId,
        action = 'Unregister-Result',
        data = 'OK'
      })
    end)

    it('should error on unregister for non-registered nest', function()
      local nestId = 'nest123'
      local msg = {
        from = nestId
      }

      assert.has_error(function()
        GetHandler('Unregister').handle(msg)
      end, 'Not Registered')
    end)
  end)

  describe('Update-Registration', function()
    it('should update owner and ACL for registered nest', function()
      local nestId = 'nest123'
      local newOwner = 'new_owner123'
      local newAcl = { ['new_admin'] = { admin = true } }
      WuzzyNestRegistry.State.Nests[nestId] = { Owner = 'old_owner', ACL = {} }
      local msg = {
        from = nestId,
        ['nest-owner'] = newOwner,
        data = json.encode(newAcl)
      }
      _G.send:clear()
      GetHandler('Update-Registration').handle(msg)

      assert.are.equal(newOwner, WuzzyNestRegistry.State.Nests[nestId].Owner)
      assert.same(newAcl, WuzzyNestRegistry.State.Nests[nestId].ACL)
      assert.spy(_G.send).was.called(1)
      assert.spy(_G.send).was.called_with({
        target = nestId,
        action = 'Update-Registration-Result',
        data = 'OK'
      })
    end)

    it('should update only owner if provided', function()
      local nestId = 'nest123'
      local newOwner = 'new_owner123'
      local oldAcl = { ['admin'] = { admin = true } }
      WuzzyNestRegistry.State.Nests[nestId] = { Owner = 'old_owner', ACL = oldAcl }
      local msg = {
        from = nestId,
        ['nest-owner'] = newOwner
      }
      _G.send:clear()
      GetHandler('Update-Registration').handle(msg)

      assert.are.equal(newOwner, WuzzyNestRegistry.State.Nests[nestId].Owner)
      assert.same(oldAcl, WuzzyNestRegistry.State.Nests[nestId].ACL)
      assert.spy(_G.send).was.called(1)
      assert.spy(_G.send).was.called_with({
        target = nestId,
        action = 'Update-Registration-Result',
        data = 'OK'
      })
    end)

    it('should update only ACL if provided', function()
      local nestId = 'nest123'
      local newAcl = { ['new_admin'] = { admin = true } }
      WuzzyNestRegistry.State.Nests[nestId] = { Owner = 'owner', ACL = {} }
      local msg = {
        from = nestId,
        data = json.encode(newAcl)
      }
      _G.send:clear()
      GetHandler('Update-Registration').handle(msg)

      assert.same(newAcl, WuzzyNestRegistry.State.Nests[nestId].ACL)
      assert.spy(_G.send).was.called(1)
      assert.spy(_G.send).was.called_with({
        target = nestId,
        action = 'Update-Registration-Result',
        data = 'OK'
      })
    end)

    it('should not update if no changes provided', function()
      local nestId = 'nest123'
      WuzzyNestRegistry.State.Nests[nestId] = { Owner = 'owner', ACL = {} }
      local msg = {
        from = nestId
      }
      assert.has_error(function()
        GetHandler('Update-Registration').handle(msg)
      end, 'No Updates Provided')
    end)

    it('should not update if not registered', function()
      local nestId = 'nest123'
      local msg = {
        from = nestId,
        ['nest-owner'] = 'owner'
      }

      assert.has_error(function()
        GetHandler('Update-Registration').handle(msg)
      end, 'Not Registered')
    end)

    it('should error on invalid ACL data', function()
      local nestId = 'nest123'
      WuzzyNestRegistry.State.Nests[nestId] = { Owner = 'owner', ACL = {} }
      local msg = {
        from = nestId,
        data = 'invalid'
      }

      assert.has_error(function()
        GetHandler('Update-Registration').handle(msg)
      end, 'Invalid ACL data')
    end)
  end)
end)
