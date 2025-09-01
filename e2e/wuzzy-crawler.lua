-- aos cnkm1lJtPajRkdf26geG-iF3Zxe6ikLCfjsSJXK0_Mw --url http://localhost:8734 --wallet ../.keys/wuzzy-deployer-rYKBcRorUBkmmnWk3BoXM5e1s71q1rdaF6v7_6gYhYE.json
-- send({ target = id, action = 'Set-Nest-Id', ['nest-id'] = '5vyXVawW_7Tigs7z3n5VStvXZw4ENWjkirlL2m3-2MI' })

send({ target = id, action = 'Add-Crawl-Tasks', data = 'https://memeticblock.com' })
send({ target = id, action = 'Add-Crawl-Tasks', data = 'https://cookbook_ao.arweave.net' })
send({ target = id, action = 'Add-Crawl-Tasks', data = 'https://cookbook.arweave.net' })
send({ target = id, action = 'Add-Crawl-Tasks', data = 'https://hyperbeam.arweave.net' })

send({ target = id, action = 'Cron' })
