Handlers.add('Cron', 'Cron', function (msg)
  print('Got Cron message:', require('json').encode(msg))
  -- send({
  --   target = id,
  --   ['relay-path'] = 'https://memeticblock.com',
  --   resolve = '~relay@1.0/call/~patch@1.0',
  --   action = 'Relay-Result'
  -- })
end)

Handlers.add('Relay-Result', 'Relay-Result', function (msg)
  print('Got Relay-Result message:', require('json').encode(msg))
  if msg.body then
    print('Relay response body received length: ' .. #msg.body)
  else
    print('No Relay response body received')
  end
end)
