import { expect } from 'chai'

import {
  AOTestHandle,
  ARIO_NETWORK_PROCESS_ID,
  AUTHORITY_ADDRESS,
  createLoader,
  NEST_ID,
  ORACLE_ADDRESS,
  OWNER_ADDRESS
} from '~/test/util/setup'

describe('Wuzzy-Crawler Cron', () => {
  let handle: AOTestHandle

  beforeEach(async () => {
    handle = (await createLoader(
      'wuzzy-crawler', {
        processTags: [
          { name: 'Nest-Id', value: NEST_ID },
          { name: 'Ario-Network-Process-Id', value: ARIO_NETWORK_PROCESS_ID },
          { name: 'Data-Oracle-Address', value: ORACLE_ADDRESS }
        ]
      }
    )).handle
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
    expect(result.Error).to.not.exist
    expect(result.Output).to.exist
    expect(result.Output).to.have.lengthOf(1)
    expect(result.Output[0]).to.include('No Crawl Tasks to process')
  })

  it('queues all assigned Crawl Tasks', async () => {
    const names = [ 'memeticblock', 'wuzzy', 'cookbook' ]
    await handle({
      From: OWNER_ADDRESS,
      Tags: [ { name: 'Action', value: 'Add-Crawl-Tasks' } ],
      Data: names.map(name => `arns://${name}`).join('\n')
    })

    const result = await handle({
      From: AUTHORITY_ADDRESS,
      Tags: [ { name: 'Action', value: 'Cron' } ]
    })

    expect(result.Error).to.not.exist
    expect(result.Messages).to.have.lengthOf(3)
    expect(result.Messages[0].Target).to.equal(ARIO_NETWORK_PROCESS_ID)
    expect(result.Messages[0].Tags).to.deep.include({
      name: 'Action',
      value: 'Record'
    })
    expect(result.Messages[1].Target).to.equal(ARIO_NETWORK_PROCESS_ID)
    expect(result.Messages[1].Tags).to.deep.include({
      name: 'Action',
      value: 'Record'
    })
    expect(result.Messages[2].Target).to.equal(ARIO_NETWORK_PROCESS_ID)
    expect(result.Messages[2].Tags).to.deep.include({
      name: 'Action',
      value: 'Record'
    })
    const sentNames = result.Messages.map(
      msg => msg.Tags.find(tag => tag.name === 'Name')?.value
    )
    expect(sentNames.sort()).to.deep.equal(names.sort())
  })
})
