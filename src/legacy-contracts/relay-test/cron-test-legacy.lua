Handlers.add('Cron', 'Cron', function (msg)
  local result = 'Got Cron message: ' .. require('json').encode(msg)
  ao.log(result)
  print(result)
  Send({
    Target = ao.id,
    Action = 'Cron-Result',
    Data = result
  })
end)
