WuzzyNestRegistry = {
  State = {
    Initialized = false,

    Nests = {}
  }
}

function WuzzyNestRegistry.init()
  local json = require('json')
  local ACL = require('..common.acl')
  require('..common.handlers.acl')(ACL)

  Handlers.add('Register', 'Register', function (msg)
    local nestId = msg.from
    assert(not WuzzyNestRegistry.State.Nests[nestId], 'Already Registered')

    local owner = msg['nest-owner']
    assert(owner and type(owner) == 'string', 'Missing or invalid Owner')

    assert(msg.data and #msg.data > 0, 'Missing ACL data')
    local acl
    pcall(function ()
      acl = json.decode(msg.data)
    end)
    assert(acl and type(acl) == 'table', 'Invalid ACL data')

    WuzzyNestRegistry.State.Nests[nestId] = {
      Owner = owner,
      ACL = acl
    }

    send({
      target = nestId,
      action = 'Register-Result',
      data = 'OK'
    })
  end)

  Handlers.add('Unregister', 'Unregister', function (msg)
    local nestId = msg.from
    assert(WuzzyNestRegistry.State.Nests[nestId], 'Not Registered')

    WuzzyNestRegistry.State.Nests[nestId] = nil

    send({
      target = nestId,
      action = 'Unregister-Result',
      data = 'OK'
    })
  end)

  Handlers.add('Update-Registration', 'Update-Registration', function (msg)
    local nestId = msg.from

    local nest = WuzzyNestRegistry.State.Nests[nestId]
    assert(nest, 'Not Registered')
    local updated = false

    local newOwner = msg['nest-owner']
    if newOwner and type(newOwner) == 'string' then
      nest.Owner = newOwner
      updated = true
    end

    if msg.data and #msg.data > 0 then
      local newAcl
      pcall(function ()
        newAcl = json.decode(msg.data)
      end)
      assert(newAcl and type(newAcl) == 'table', 'Invalid ACL data')
      nest.ACL = newAcl
      updated = true
    end

    assert(updated, 'No Updates Provided')

    send({
      target = nestId,
      action = 'Update-Registration-Result',
      data = 'OK'
    })
  end)

  Handlers.add('List-Nests', 'List-Nests', function (msg)
    local nests = {}
    for nestId, info in pairs(WuzzyNestRegistry.State.Nests) do
      table.insert(nests, {
        Id = nestId,
        Owner = info.Owner
      })
    end

    send({
      target = msg.from,
      action = 'List-Nests-Result',
      data = json.encode(nests)
    })
  end)

  Handlers.add('Get-Admins', 'Get-Admins', function (msg)
    local nestId = msg['nest-id']
    assert(nestId and type(nestId) == 'string', 'Missing or invalid nest-id')

    local nest = WuzzyNestRegistry.State.Nests[nestId]
    assert(nest, 'Nest not found')

    local admins = {}
    for user, roles in pairs(nest.ACL) do
      if type(roles) == 'table' and roles['admin'] then
        table.insert(admins, user)
      end
    end

    send({
      target = msg.from,
      action = 'Get-Admins-Result',
      data = json.encode({
        NestId = nestId,
        Admins = admins
      })
    })
  end)

  Handlers.add('Get-ACL-Users', 'Get-ACL-Users', function (msg)
    local nestId = msg['nest-id']
    assert(nestId and type(nestId) == 'string', 'Missing or invalid nest-id')

    local nest = WuzzyNestRegistry.State.Nests[nestId]
    assert(nest, 'Nest not found')

    local users = {}
    for user in pairs(nest.ACL) do
      table.insert(users, user)
    end

    send({
      target = msg.from,
      action = 'Get-ACL-Users-Result',
      data = json.encode({
        NestId = nestId,
        Users = users
      })
    })
  end)

  WuzzyNestRegistry.State.Initialized = true
end

if not WuzzyNestRegistry.State.Initialized then
  WuzzyNestRegistry.init()
end
