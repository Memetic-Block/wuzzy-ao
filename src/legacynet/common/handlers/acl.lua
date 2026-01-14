-- ACL handlers for AO legacynet
-- Uses Handlers.utils.hasMatchingTag pattern and ao.send()

return function (ACL)
  local json = require('json')

  Handlers.add(
    'Update-Roles',
    Handlers.utils.hasMatchingTag('Action', 'Update-Roles'),
    function (msg)
      ACL.utils.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Update-Roles' })

      ACL.utils.updateRoles(json.decode(msg.Data))

      ao.send({
        Target = msg.From,
        Action = 'Update-Roles-Response',
        Data = 'OK'
      })
    end
  )

  Handlers.add(
    'View-Roles',
    Handlers.utils.hasMatchingTag('Action', 'View-Roles'),
    function (msg)
      ao.send({
        Target = msg.From,
        Action = 'View-Roles-Response',
        Data = json.encode(ACL.state)
      })
    end
  )
end
