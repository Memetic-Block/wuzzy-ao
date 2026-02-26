-- Handlers.add('GET', 'GET', function (msg)
--   assert(type(msg.Tags['URL']) == 'string', 'URL tag is required for GET request')
--   print('Received GET request from ' .. msg.From .. ' with URL ' .. msg.Tags['URL'])
--   Send({
--     target = ao.id,
--     ['relay-path'] = msg.Tags['URL'],
--     resolve = '~relay@1.0/call/~patch@1.0',
--     -- Action = 'GET-Result'
--   })
-- end)

Handlers.add('GET-Result', function(msg) return ao.isTrusted(msg) and msg.Tags['Status'] == '200' end, function (msg)
  print('Received GET-Result from ' .. msg.From)
  if msg.Body then
    print('GET response body: ' .. msg.Body)
  else
    print('No GET response body received')
  end
end)

Handlers.add('GET-Failed', function(msg) return ao.isTrusted(msg) and msg.Tags['Status'] ~= '200' end, function (msg)
  print('Received GET-Failed from ' .. msg.From)
  print('GET request failed with status: ' .. (msg.Tags['Status'] or 'unknown'))
end)

-- Handlers.add('POST', 'POST', function (msg)
--   print(
--     'Received POST request from ' .. msg.From ..
--       ' with URL ' .. msg.Tags['URL'] .. ' and body ' .. msg.Tags['BODY']
--   )
--   assert(type(msg.Tags['URL']) == 'string', 'URL tag is required for POST request')
--   Send({
--     Target = ao.id,
--     ['relay-method'] = 'POST',
--     ['relay-path'] = msg.Tags['URL'],
--     ['relay-body'] = msg.Tags['BODY'],
--     -- ['relay-commit-request'] = 'true',
--     resolve = '~relay@1.0/call/~patch@1.0',
--     Action = 'POST-Result'
--   })
-- end)

-- Handlers.add('POST-Result', 'POST-Result', function (msg)
--   print('Received POST-Result from ' .. msg.From)
--   if msg.body then
--     print('POST response body: ' .. msg.body)
--   else
--     print('No POST response body received')
--   end
-- end)

-- Send({ target = id, action = 'POST', url = 'https://arweave.net/graphql', data = '{ "operationName": null, "query": "{   transactions(ids:["iaiAqmcYrviugZq9biUZKJIAi_zIT_mgFHAWZzMvDuk"]) {     pageInfo {       hasNextPage     }     edges {       cursor       node {         id         anchor         signature         recipient         owner {           address           key         }         fee {           winston           ar         }         quantity {           winston           ar         }         data {           size           type         }         tags {           name           value         }         block {           id           timestamp           height           previous         }         parent {           id         }       }     }   } }", "variables": {} }' })
-- Send({ target = id, action = 'POST', url = 'https://jsonplaceholder.typicode.com/posts', data = '{"title": "foo", "body": "bar", "userId": 1}' })

-- Send({ target = ao.id, ['relay-method'] = 'GET', ['relay-path'] = 'https://arweave.net/info', resolve = '~relay@1.0/call' })