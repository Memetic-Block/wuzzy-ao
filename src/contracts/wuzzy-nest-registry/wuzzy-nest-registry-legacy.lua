local WuzzyNestRegistry = {
  State = {
    WuzzyNestModuleId = nil,
    WuzzyNestSpawnRefs = {},
    WuzzyNests = {}
  }
}

WuzzyNestRegistry.State.WuzzyNestModuleId =
  ao.env.Module.Id or
    ao.env.Process.Tags['Wuzzy-Nest-Module-Id']

function WuzzyNestRegistry.init()
  local json = require('json')
  local ACL = require('..common.acl')
  local base64 = require('.base64')
  ---@diagnostic disable-next-line: missing-parameter
  local WuzzyNestCode = base64.decode(
    require('..wuzzy-nest.wuzzy-nest-stringified')
  )

  require('..common.handlers.acl')(ACL)
  require('..common.handlers.state')(WuzzyNestRegistry)

  Handlers.add(
    'Set-Wuzzy-Nest-Module-Id',
    Handlers.utils.hasMatchingTag('Action', 'Set-Wuzzy-Nest-Module-Id'),
    function(msg)
      ACL.assertHasOneOfRole(
        msg.From,
        { 'owner', 'admin', 'Set-Wuzzy-Nest-Module-Id' }
      )

      assert(
        type(msg['Wuzzy-Nest-Module-Id']) == 'string' and
          #msg['Wuzzy-Nest-Module-Id'] == 43,
        'A valid Wuzzy-Nest-Module-Id is required'
      )
      local newWuzzyNestModuleId = msg['Wuzzy-Nest-Module-Id']

      WuzzyNestRegistry.State.WuzzyNestModuleId = newWuzzyNestModuleId

      Send({
        Target = msg.From,
        Action = 'Set-Wuzzy-Nest-Module-Id-Result',
        Data = 'OK',
        ['Wuzzy-Nest-Module-Id'] = newWuzzyNestModuleId
      })
    end
  )

  Handlers.add(
    'Create-Nest',
    Handlers.utils.hasMatchingTag('Action', 'Create-Nest'),
    function (msg)
      local nestName = msg.Tags['Nest-Name'] or 'My Wuzzy Nest'
      local xCreateNestId = msg.Id
      Spawn(WuzzyNestRegistry.State.WuzzyNestModuleId, {
        Tags = {
          ['App-Name'] = 'Wuzzy',
          ['Contract-Name'] = 'wuzzy-nest',
          ['Authority'] = ao.authorities[1],
          ['X-Create-Nest-Id'] = xCreateNestId,
          ['Nest-Name'] = nestName,
          ['Nest-Creator'] = msg.From
        }
      })
      WuzzyNestRegistry.State.WuzzyNestSpawnRefs[msg.Id] = {
        Creator = msg.From,
        NestName = nestName
      }
      Send({
        Target = msg.From,
        Action = 'Create-Nest-Result',
        Data = 'OK',
        ['X-Create-Nest-Id'] = xCreateNestId
      })
    end
  )

  Handlers.add(
    'Spawned',
    Handlers.utils.hasMatchingTag('Action', 'Spawned'),
    function (msg)
      if msg.From ~= ao.id then
        ao.log(
          'Ignoring Spawned message from unknown process: ' ..
            tostring(msg.From)
        )
        return
      end

      local fromProcess = msg.Tags['From-Process']
      if fromProcess ~= ao.id then
        ao.log(
          'Ignoring Spawned message from unknown process: ' ..
            tostring(fromProcess)
        )
        return
      end

      local ref = msg.Tags['X-Create-Nest-Id']
      if not ref then
        ao.log('Ignoring Spawned message without X-Create-Nest-Id tag')
        return
      end

      local nestRef = WuzzyNestRegistry.State.WuzzyNestSpawnRefs[ref]
      if not nestRef then
        ao.log(
          'Ignoring Spawned message with unknown X-Create-Nest-Id: ' ..
            tostring(ref)
        )
        return
      end

      local nestId = msg.Tags['Process']
      if not nestId or type(nestId) ~= 'string' then
        ao.log(
          'Ignoring Spawned message without valid Process tag: ' ..
            tostring(nestId)
        )
        return
      end

      Send({
        Target = nestId,
        Action = 'Eval',
        Data = WuzzyNestCode
      })

      WuzzyNestRegistry.State.WuzzyNests[nestId] = {
        Ref = ref,
        Name = nestRef.NestName,
        Creator = nestRef.Creator,
        Owner = nestRef.Creator,
        Roles = {}
      }
      WuzzyNestRegistry.State.WuzzyNestSpawnRefs[ref] = nil

      Send({
        Target = nestRef.Creator,
        Action = 'Nest-Spawned',
        Data = 'OK',
        ['Nest-Id'] = nestId
      })
    end
  )

  Handlers.add(
    'Nest-Update',
    Handlers.utils.hasMatchingTag('Action', 'Nest-Update'),
    function (msg)
      local nest = WuzzyNestRegistry.State.WuzzyNests[msg.From]
      assert(nest, 'Unknown Wuzzy-Nest process: ' .. tostring(msg.From))
      assert(msg.Data, 'Update data is required for Nest-Update')

      local nestUpdate = json.decode(msg.Data)

      if nestUpdate.Owner then
        assert(
          type(nestUpdate.Owner) == 'string',
          'Owner must be a string address'
        )
        nest.Owner = nestUpdate.Owner
      end

      if nestUpdate.Name then
        assert(type(nestUpdate.Name) == 'string', 'Name must be a string')
        assert(#nestUpdate.Name <= 255, 'Name must be at most 255 characters')
        nest.Name = nestUpdate.Name
      end

      if nestUpdate.Roles then
        ACL.updateRoles(nestUpdate.Roles, nest)
      end

      Send({
        Target = msg.From,
        Action = 'Nest-Update-Result',
        Data = 'OK',
        ['Nest-Update-Message-Id'] = msg.Id
      })
    end
  )
end

WuzzyNestRegistry.init()
