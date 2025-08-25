import { expect } from 'chai'

import {
  ALICE_ADDRESS,
  AOTestHandle,
  ARIO_NETWORK_PROCESS_ID,
  AUTHORITY_ADDRESS,
  createLoader,
  MODULE_ID,
  ORACLE_ADDRESS,
  OWNER_ADDRESS,
  PROCESS_ID
} from '~/test/util/setup'

describe('Wuzzy-Nest Create-Crawler', () => {
  let handle: AOTestHandle

  beforeEach(async () => {
    handle = (await createLoader('wuzzy-nest')).handle
  })

  it('spawns a new Wuzzy-Crawler process & tracks the spawn', async () => {
      const result = await handle({
        From: OWNER_ADDRESS,
        Tags: [ { name: 'Action', value: 'Create-Crawler' } ]
      })
      expect(result.Error).to.not.exist
      expect(result.Spawns).to.have.lengthOf(1)
      expect(result.Spawns[0].Tags).to.deep.include({
        name: 'Module',
        value: MODULE_ID
      })
      expect(result.Spawns[0].Tags).to.deep.include({
        name: 'Contract-Name',
        value: 'wuzzy-crawler'
      })
      expect(result.Spawns[0].Tags).to.deep.include({
        name: 'App-Name',
        value: 'Wuzzy'
      })
      expect(result.Spawns[0].Tags).to.deep.include({
        name: 'Authority',
        value: AUTHORITY_ADDRESS
      })
      const spawnRef = result.Spawns[0].Tags.find(
        tag => tag.name === 'X-Create-Crawler-Id'
      )?.value
      expect(spawnRef).to.exist
  
      expect(result.Messages).to.have.lengthOf(1)
      expect(result.Messages[0].Data).to.exist
      expect(result.Messages[0].Data).to.equal('OK')
      expect(result.Messages[0].Tags).to.deep.include({
        name: 'Action',
        value: 'Create-Crawler-Result'
      })
      expect(result.Messages[0].Tags).to.deep.include({
        name: 'X-Create-Crawler-Id',
        value: spawnRef
      })
  
      const viewStateResult = await handle({
        From: OWNER_ADDRESS,
        Tags: [ { name: 'Action', value: 'View-State' } ]
      })
      expect(viewStateResult.Error).to.not.exist
      expect(viewStateResult.Messages).to.have.lengthOf(1)
      expect(viewStateResult.Messages[0].Data).to.exist
      const state = JSON.parse(viewStateResult.Messages[0].Data)
      expect(state.CrawlerSpawnRefs[spawnRef!]).to.exist
      expect(state.CrawlerSpawnRefs[spawnRef!]).to.deep.equal({
        Creator: OWNER_ADDRESS,
        CrawlerName: 'My Wuzzy Crawler'
      })
  })

  it('notifies creator of new crawler spawn & tracks crawler creators', async () => {
    const newProcessId = 'new-process-id'.padEnd(43, '0')
    const result = await handle({
      From: OWNER_ADDRESS,
      Tags: [ { name: 'Action', value: 'Create-Crawler' } ]
    })
  
    expect(result.Error).to.not.exist
    const spawnRef = result.Spawns[0].Tags.find(
      tag => tag.name === 'X-Create-Crawler-Id'
    )?.value
    expect(spawnRef).to.exist

    const spawnedResult = await handle({
      From: PROCESS_ID,
      Tags: [
        { name: 'Action', value: 'Spawned' },
        { name: 'X-Create-Crawler-Id', value: spawnRef! },
        { name: 'From-Process', value: PROCESS_ID },
        { name: 'Process', value: newProcessId }
      ]
    })
    expect(spawnedResult.Error).to.not.exist
    expect(spawnedResult.Messages).to.have.lengthOf(2)

    expect(spawnedResult.Messages[0].Target).to.equal(newProcessId)
    expect(spawnedResult.Messages[0].Tags).to.deep.include({
      name: 'Action',
      value: 'Eval'
    })
    expect(spawnedResult.Messages[0].Tags).to.deep.include({
      name: 'Ario-Network-Process-Id',
      value: ARIO_NETWORK_PROCESS_ID
    })
    expect(spawnedResult.Messages[0].Tags).to.deep.include({
      name: 'Data-Oracle-Address',
      value: ORACLE_ADDRESS
    })
    expect(spawnedResult.Messages[0].Data).to.exist

    expect(spawnedResult.Messages[1].Target).to.equal(OWNER_ADDRESS)
    expect(spawnedResult.Messages[1].Tags).to.deep.include({
      name: 'Action',
      value: 'Crawler-Spawned'
    })
    expect(spawnedResult.Messages[1].Data).to.equal('OK')
    expect(spawnedResult.Messages[1].Tags).to.deep.include({
      name: 'Crawler-Id',
      value: newProcessId
    })

    const viewStateResult = await handle({
      From: OWNER_ADDRESS,
      Tags: [ { name: 'Action', value: 'View-State' } ]
    })
    expect(viewStateResult.Error).to.not.exist
    expect(viewStateResult.Messages).to.have.lengthOf(1)
    expect(viewStateResult.Messages[0].Data).to.exist
    const state = JSON.parse(viewStateResult.Messages[0].Data)
    expect(state.Crawlers[newProcessId]).to.exist
    expect(state.Crawlers[newProcessId]).to.deep.equal({
      Ref: spawnRef,
      Name: 'My Wuzzy Crawler',
      Creator: OWNER_ADDRESS,
      Owner: OWNER_ADDRESS,
      Roles: []
    })
  })

  it('throws on Create-Crawler messages from unauthorized callers', async () => {
    const result = await handle({
      From: ALICE_ADDRESS,
      Tags: [ { name: 'Action', value: 'Create-Crawler' } ]
    })
    expect(result.Error).to.exist
    expect(result.Error).to.include('Permission Denied')
  })

  it('ignores Spawned messages without known X-Create-Crawler-Id', async () => {
    const spawnedResult = await handle({
      From: OWNER_ADDRESS,
      Tags: [
        { name: 'Action', value: 'Spawned' },
        { name: 'X-Create-Crawler-Id', value: 'spawn-ref' },
        { name: 'From-Process', value: PROCESS_ID },
        { name: 'Process', value: 'new-process-id'.padEnd(43, '0') }
      ]
    })

    expect(spawnedResult.Error).to.not.exist
    expect(spawnedResult.Messages).to.have.lengthOf(0)
  })

  it('ignores Spawned messages from unknown process', async () => {
    const result = await handle({
      From: OWNER_ADDRESS,
      Tags: [ { name: 'Action', value: 'Create-Crawler' } ]
    })
  
    expect(result.Error).to.not.exist
    expect(result.Spawns).to.have.lengthOf(1)
    const spawnRef = result.Spawns[0].Tags.find(
      tag => tag.name === 'X-Create-Crawler-Id'
    )?.value
    expect(spawnRef).to.exist
    
    const spawnedResult = await handle({
      From: OWNER_ADDRESS,
      Tags: [
        { name: 'Action', value: 'Spawned' },
        { name: 'X-Create-Crawler-Id', value: spawnRef! },
        { name: 'From-Process', value: 'unknown-process'.padEnd(43, 'q') },
        { name: 'Process', value: 'new-process-id'.padEnd(43, '0')}
      ]
    })
    expect(spawnedResult.Error).to.not.exist
    expect(spawnedResult.Messages).to.have.lengthOf(0)
  })

  it('ignores Spawned messages from unknown caller', async () => {
    const newProcessId = 'new-process-id'.padEnd(43, '0')
    const createResult = await handle({
      From: OWNER_ADDRESS,
      Tags: [ { name: 'Action', value: 'Create-Crawler' } ]
    })
    expect(createResult.Error).to.not.exist
    const spawnRef = createResult.Spawns[0].Tags.find(
      tag => tag.name === 'X-Create-Crawler-Id'
    )?.value
    expect(spawnRef).to.exist

    const result = await handle({
      From: OWNER_ADDRESS,
      Tags: [
        { name: 'Action', value: 'Spawned' },
        { name: 'X-Create-Crawler-Id', value: spawnRef! },
        { name: 'From-Process', value: PROCESS_ID },
        { name: 'Process', value: newProcessId }
      ]
    })

    expect(result.Error).to.not.exist
    expect(result.Messages).to.have.lengthOf(0)
  })

  it('ignores Spawned messages without any X-Create-Crawler-Id tag', async () => {
    const result = await handle({
      From: OWNER_ADDRESS,
      Tags: [ { name: 'Action', value: 'Create-Crawler' } ]
    })
    expect(result.Error).to.not.exist

    const spawnedResult = await handle({
      From: PROCESS_ID,
      Tags: [
        { name: 'Action', value: 'Spawned' },
        { name: 'From-Process', value: PROCESS_ID },
        { name: 'Process', value: 'new-process-id'.padEnd(43, '0') }
      ]
    })

    expect(spawnedResult.Error).to.not.exist
    expect(spawnedResult.Messages).to.have.lengthOf(0)
  })

  it('ignores Spawned messages without Process tag', async () => {
    const result = await handle({
      From: OWNER_ADDRESS,
      Tags: [ { name: 'Action', value: 'Create-Crawler' } ]
    })
    expect(result.Error).to.not.exist
    const spawnRef = result.Spawns[0].Tags.find(
      tag => tag.name === 'X-Create-Crawler-Id'
    )?.value
    expect(spawnRef).to.exist

    const spawnedResult = await handle({
      From: OWNER_ADDRESS,
      Tags: [
        { name: 'Action', value: 'Spawned' },
        { name: 'X-Create-Crawler-Id', value: spawnRef! },
        { name: 'From-Process', value: PROCESS_ID }
      ]
    })

    expect(spawnedResult.Error).to.not.exist
    expect(spawnedResult.Messages).to.have.lengthOf(0)
  })

  it('clears spawn refs on Spawned messages', async () => {
    const result = await handle({
      From: OWNER_ADDRESS,
      Tags: [ { name: 'Action', value: 'Create-Crawler' } ]
    })
    expect(result.Error).to.not.exist
    const spawnRef = result.Spawns[0].Tags.find(
      tag => tag.name === 'X-Create-Crawler-Id'
    )?.value
    expect(spawnRef).to.exist
    const spawnedResult = await handle({
      From: PROCESS_ID,
      Tags: [
        { name: 'Action', value: 'Spawned' },
        { name: 'X-Create-Crawler-Id', value: spawnRef! },
        { name: 'From-Process', value: PROCESS_ID },
        { name: 'Process', value: 'new-process-id'.padEnd(43, '0') }
      ]
    })
    expect(spawnedResult.Error).to.not.exist

    const viewStateResult = await handle({
      From: OWNER_ADDRESS,
      Tags: [ { name: 'Action', value: 'View-State' } ]
    })
    expect(viewStateResult.Error).to.not.exist
    expect(viewStateResult.Messages).to.have.lengthOf(1)
    expect(viewStateResult.Messages[0].Data).to.exist
    const state = JSON.parse(viewStateResult.Messages[0].Data)
    expect(state.CrawlerSpawnRefs[spawnRef!]).to.not.exist
  })
})
