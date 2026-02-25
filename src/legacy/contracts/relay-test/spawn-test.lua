State = {
  SpawnRefs = {}
}

Handlers.add('Create-Child', 'Create-Child', function (msg)
  local xCreateId = msg.id
  print('before spawn')
  spawn(module, {
    authority = authorities[1],
    ['X-Create-Id'] = xCreateId,
    ['Creator'] = msg.from
  })
  print('after spawn')
  State.SpawnRefs[xCreateId] = { Creator = msg.from }
  send({
    device = 'patch@1.0',
    cache = State
  })
end)

Handlers.add('Spawned', 'Spawned', function (msg)
  print('Got Spawned message: ' .. require('json').encode(msg))
  send({
    target = msg['Process'],
    action = 'Eval',
    data = [[
    print('Hello from spawned process', id)
    send({ target = msg.from, action = 'Child-Spawned', data = 'Child process ' .. id .. ' spawned successfully!' })
    ]]
  })
end)

Handlers.add('Child-Spawned', 'Child-Spawned', function (msg)
  print('Got Child-Spawned message: ' .. require('json').encode(msg))
end)
