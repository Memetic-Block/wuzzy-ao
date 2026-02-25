Prices = Prices or {}
PRICE_FEED_URL = 'https://68a3a5edc123272fb9b02092.mockapi.io/prices/feed'

Handlers.add('Set-Prices', 'Set-Prices', function(msg)
  if msg.body then
    print('Received price feed from', msg['relay-path'])
    Prices = require('json').decode(msg.body)
    print('Updated prices:')
    print(Prices)
  else
    print('No price feed received')
  end
end)

Handlers.add('Get-Prices', 'Get-Prices', function(msg)
  local url = msg.url or PRICE_FEED_URL
  print('Getting price feed...' .. url)
  -- print('msg: ' .. require('json').encode(msg))
  send({
    target = id,
    ['relay-path'] = url,
    resolve = '~relay@1.0/call/~patch@1.0',
    action = 'Set-Prices'
  })
end)
