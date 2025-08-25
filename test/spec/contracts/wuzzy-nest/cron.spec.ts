import { expect } from 'chai'

import {
  AOTestHandle,
  AUTHORITY_ADDRESS,
  createLoader,
  OWNER_ADDRESS
} from '~/test/util/setup'

describe.skip('Wuzzy-Nest Cron', () => {
  let handle: AOTestHandle

  beforeEach(async () => {
    handle = (await createLoader('wuzzy-nest')).handle
  })

  it('ignores unknown Cron messages', async () => {
    const result = await handle({
      From: OWNER_ADDRESS,
      Tags: [ { name: 'Action', value: 'Cron' } ]
    })
    expect(result.Error).to.exist
    expect(result.Error).to.include('Unauthorized Cron Caller')
  })

  it('does nothing if it has no Crawl Tasks', async () => {
    const result = await handle({
      From: AUTHORITY_ADDRESS,
      Tags: [ { name: 'Action', value: 'Cron' } ]
    })
    expect(result.Output).to.exist
    expect(result.Output).to.have.lengthOf(1)
    expect(result.Output[0]).to.include('No Crawl Tasks to distribute')
  })

  it('does nothing if it has no Crawlers', async () => {
    await handle({
      From: OWNER_ADDRESS,
      Tags: [ { name: 'Action', value: 'Add-Crawl-Tasks' } ],
      Data: 'arns://memeticblock\narns://wuzzy\narns://cookbook'
    })
    const result = await handle({
      From: AUTHORITY_ADDRESS,
      Tags: [ { name: 'Action', value: 'Cron' } ]
    })
    expect(result.Output).to.exist
    expect(result.Output).to.have.lengthOf(1)
    expect(result.Output[0]).to.include('No Crawlers to distribute Crawl Tasks')
  })

  it('distributes Crawl Tasks to Crawlers')
})
