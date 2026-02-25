return function (ACL)
  local json = require('json')

  Handlers.add('Update-Roles', 'Update-Roles', function (msg)
    ACL.assertHasOneOfRole(msg.from, { 'owner', 'admin', 'Update-Roles' })

    ACL.updateRoles(json.decode(msg.data))

    send({
      target = msg.From,
      action = 'Update-Roles-Response',
      data = 'OK'
    })
  end)

  Handlers.add('View-Roles', 'View-Roles', function (msg)
    send({
      target = msg.from,
      action = 'View-Roles-Response',
      data = json.encode(ACL.State)
    })
  end)
end
