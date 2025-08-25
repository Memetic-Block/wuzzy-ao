Handlers.add('GET', 'GET', function (msg)
  assert(type(msg.url) == 'string', 'URL tag is required for GET request')
  print(
    'Received GET request from ' .. msg.from ..
      ' with URL ' .. msg.url
  )
  send({
    target = id,
    ['relay-path'] = msg.url,
    resolve = '~relay@1.0/call/~patch@1.0',
    action = 'GET-Result'
  })
end)

Handlers.add('GET-Result', 'GET-Result', function (msg)
  print('Received GET-Result from ' .. msg.from)
  if msg.body then
    print('GET response body: ' .. msg.body)
  else
    print('No GET response body received')
  end
end)

Handlers.add('POST', 'POST', function (msg)
  -- print('POST msg: ' .. require('json').encode(msg))
  print(
    'Received POST request from ' .. msg.from ..
      ' with URL ' .. msg.url .. ' and body ' .. msg.data
  )
  assert(type(msg.url) == 'string', 'URL tag is required for POST request')
  send({
    target = id,
    ['relay-method'] = 'POST',
    ['relay-path'] = msg.url,
    ['relay-body'] = msg.data,
    -- ['relay-commit-request'] = 'true',
    resolve = '~relay@1.0/call/~patch@1.0',
    action = 'POST-Result'
  })
end)

Handlers.add('POST-Result', 'POST-Result', function (msg)
  print('Received POST-Result from ' .. msg.from)
  if msg.body then
    print('POST response body: ' .. msg.body)
  else
    print('No POST response body received')
  end
end)

-- send({ target = id, action = 'POST', url = 'https://arweave.net/graphql', data = '{ "operationName": null, "query": "{   transactions(ids:["iaiAqmcYrviugZq9biUZKJIAi_zIT_mgFHAWZzMvDuk"]) {     pageInfo {       hasNextPage     }     edges {       cursor       node {         id         anchor         signature         recipient         owner {           address           key         }         fee {           winston           ar         }         quantity {           winston           ar         }         data {           size           type         }         tags {           name           value         }         block {           id           timestamp           height           previous         }         parent {           id         }       }     }   } }", "variables": {} }' })
-- send({ target = id, action = 'POST', url = 'https://jsonplaceholder.typicode.com/posts', data = '{"title": "foo", "body": "bar", "userId": 1}' })