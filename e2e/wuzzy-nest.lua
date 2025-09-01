-- aos 0BNZK-wNLzdIDHFib3jIQI31eVQVZY4CFzZliKXi2uk --url http://localhost:8734 --wallet ../.keys/wuzzy-deployer-rYKBcRorUBkmmnWk3BoXM5e1s71q1rdaF6v7_6gYhYE.json
send({ target = id, action = 'Index-Document', data = 'Wuzzy', ['document-last-crawled-at'] = tostring(os.time()), ['document-url'] = 'https://wuzzy.io/doc1', ['document-content-type'] = 'text/plain' })
send({ target = id, action = 'Index-Document', data = 'Wuzzy S', ['document-last-crawled-at'] = tostring(os.time()), ['document-url'] = 'https://wuzzy.io/doc2', ['document-content-type'] = 'text/plain' })
send({ target = id, action = 'Index-Document', data = 'Wuzzy AO Search', ['document-last-crawled-at'] = tostring(os.time()), ['document-url'] = 'https://wuzzy.io/doc3', ['document-content-type'] = 'text/plain' })
send({ target = id, action = 'Index-Document', data = 'Wuzzy Search', ['document-last-crawled-at'] = tostring(os.time()), ['document-url'] = 'https://wuzzy.io/doc4', ['document-content-type'] = 'text/plain' })
send({ target = id, action = 'Index-Document', data = 'Wuzzy Wuzzy Search Search', ['document-last-crawled-at'] = tostring(os.time()), ['document-url'] = 'https://wuzzy.io/doc5', ['document-content-type'] = 'text/plain' })
send({ target = id, action = 'Index-Document', data = 'Wuzzy Wuzzy Wuzzy Search Search Search', ['document-last-crawled-at'] = tostring(os.time()), ['document-url'] = 'https://wuzzy.io/doc6', ['document-content-type'] = 'text/plain' })

send({ target = id, action = 'Search', query = 'Wuzzy', ['search-type'] = 'bm25' })

-- send({ target = id, action = 'Add-Crawler', ['crawler-id'] = 'cnkm1lJtPajRkdf26geG-iF3Zxe6ikLCfjsSJXK0_Mw' })
send({ target = id, action = 'Add-Crawler', ['crawler-id'] = 'SS6YcwQhwZ2Ww-83Dd22L9-E9hzU_wf-2MYeY9hWQj0' })
