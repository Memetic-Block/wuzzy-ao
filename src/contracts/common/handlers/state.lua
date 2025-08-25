return function (ProcessWithState)
  local json = require('json')

  Handlers.add('View-State', 'View-State', function (msg)
    send({
      target = msg.from,
      action = 'View-State-Response',
      data = json.encode(ProcessWithState.State)
    })
  end)
end
