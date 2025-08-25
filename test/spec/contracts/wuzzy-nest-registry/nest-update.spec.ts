import { expect } from 'chai'

import {
  ALICE_ADDRESS,
  AOTestHandle,
  BOB_ADDRESS,
  createLoader,
  OWNER_ADDRESS,
  PROCESS_ID
} from '~/test/util/setup'

describe('Wuzzy-Nest-Registry Nest-Update', () => {
  let handle: AOTestHandle
  const wuzzyNestModuleId = 'wuzzy-nest-module'.padEnd(43, '0')
  const makeNest = async function () {
    const nestId = 'new-nest-id'.padEnd(43, '0')
    const createResult = await handle({
      From: ALICE_ADDRESS,
      Tags: [ { name: 'Action', value: 'Create-Nest' } ]
    })
    expect(createResult.Error).to.not.exist
    const spawnRef = createResult.Spawns[0].Tags.find(
      tag => tag.name === 'X-Create-Nest-Id'
    )?.value
    expect(spawnRef).to.exist
    const spawnedResult = await handle({
      From: PROCESS_ID,
      Tags: [
        { name: 'Action', value: 'Spawned' },
        { name: 'X-Create-Nest-Id', value: spawnRef! },
        { name: 'From-Process', value: PROCESS_ID },
        { name: 'Process', value: nestId }
      ]
    })
    expect(spawnedResult.Error).to.not.exist

    return nestId
  }

  beforeEach(async () => {
    handle = (await createLoader(
      'wuzzy-nest-registry',
      {
        processTags: [
          { name: 'Wuzzy-Nest-Module-Id', value: wuzzyNestModuleId }
        ]
      }
    )).handle
  })

  it('errors on Nest-Update from unknown processes', async () => {
    const unknownProcessId = 'unknown-process-id'.padEnd(43, '0')
    const result = await handle({
      From: unknownProcessId,
      Tags: [
        { name: 'Action', value: 'Nest-Update' },
        { name: 'Nest-Name', value: 'TestNest' }
      ]
    })
    expect(result.Error).to.exist
    expect(result.Error).to.include(
      `Unknown Wuzzy-Nest process: ${unknownProcessId}`
    )
  })

  it('requires update data on Nest-Update', async () => {
    const nestId = await makeNest()

    const result = await handle({
      From: nestId,
      Tags: [ { name: 'Action', value: 'Nest-Update' } ]
    })

    expect(result.Error).to.exist
    expect(result.Error).to.include('Update data is required for Nest-Update')
  })

  it('validates Owner on Nest-Update', async () => {
    const nestId = await makeNest()

    const result = await handle({
      From: nestId,
      Tags: [ { name: 'Action', value: 'Nest-Update' } ],
      Data: JSON.stringify({ Owner: 1 })
    })

    expect(result.Error).to.exist
    expect(result.Error).to.include('Owner must be a string address')
  })

  it('updates Owner on Nest-Update', async () => {
    const nestId = await makeNest()
    const messageId = 'message-id'.padEnd(43, '7')
    const result = await handle({
      Id: messageId,
      From: nestId,
      Tags: [ { name: 'Action', value: 'Nest-Update' } ],
      Data: JSON.stringify({ Owner: BOB_ADDRESS })
    })

    expect(result.Error).to.not.exist
    expect(result.Messages).to.have.lengthOf(1)
    expect(result.Messages[0].Data).to.equal('OK')
    expect(result.Messages[0].Tags).to.deep.include({
      name: 'Action',
      value: 'Nest-Update-Result'
    })
    expect(result.Messages[0].Tags).to.deep.include({
      name: 'Nest-Update-Message-Id',
      value: messageId
    })

    const viewStateResult = await handle({
      From: OWNER_ADDRESS,
      Tags: [ { name: 'Action', value: 'View-State' } ]
    })
    expect(viewStateResult.Error).to.not.exist
    expect(viewStateResult.Messages).to.have.lengthOf(1)
    expect(viewStateResult.Messages[0].Data).to.exist
    const state = JSON.parse(viewStateResult.Messages[0].Data)
    expect(state.WuzzyNests[nestId]).to.exist
    expect(state.WuzzyNests[nestId].Owner).to.equal(BOB_ADDRESS)
  })

  it('validates Name on Nest-Update', async () => {
    const nestId = await makeNest()

    const numberNestNameResult = await handle({
      From: nestId,
      Tags: [ { name: 'Action', value: 'Nest-Update' } ],
      Data: JSON.stringify({ Name: 1 })
    })

    expect(numberNestNameResult.Error).to.exist
    expect(numberNestNameResult.Error).to.include('Name must be a string')

    const tooLongNestNameResult = await handle({
      From: nestId,
      Tags: [ { name: 'Action', value: 'Nest-Update' } ],
      Data: JSON.stringify({ Name: 'a'.repeat(256) })
    })
    expect(tooLongNestNameResult.Error).to.exist
    expect(tooLongNestNameResult.Error).to.include(
      'Name must be at most 255 characters'
    )
  })

  it('updates Name on Nest-Update', async () => {
    const nestId = await makeNest()
    const messageId = 'message-id'.padEnd(43, '7')
    const newName = 'Updated Wuzzy Nest Name'
    const result = await handle({
      Id: messageId,
      From: nestId,
      Tags: [ { name: 'Action', value: 'Nest-Update' } ],
      Data: JSON.stringify({ Name: newName })
    })

    expect(result.Error).to.not.exist
    expect(result.Messages).to.have.lengthOf(1)
    expect(result.Messages[0].Data).to.equal('OK')
    expect(result.Messages[0].Tags).to.deep.include({
      name: 'Action',
      value: 'Nest-Update-Result'
    })
    expect(result.Messages[0].Tags).to.deep.include({
      name: 'Nest-Update-Message-Id',
      value: messageId
    })

    const viewStateResult = await handle({
      From: OWNER_ADDRESS,
      Tags: [ { name: 'Action', value: 'View-State' } ]
    })
    expect(viewStateResult.Error).to.not.exist
    expect(viewStateResult.Messages).to.have.lengthOf(1)
    expect(viewStateResult.Messages[0].Data).to.exist
    const state = JSON.parse(viewStateResult.Messages[0].Data)
    expect(state.WuzzyNests[nestId]).to.exist
    expect(state.WuzzyNests[nestId].Name).to.equal(newName)
  })

  it('validates Roles on Nest-Update', async () => {
    const nestId = await makeNest()

    const grantNonStringRoleResult = await handle({
      From: nestId,
      Tags: [ { name: 'Action', value: 'Nest-Update' } ],
      Data: JSON.stringify({ Roles: { Grant: { [BOB_ADDRESS]: [ 1 ] } } })
    })

    expect(grantNonStringRoleResult.Error).to.exist
    expect(grantNonStringRoleResult.Error).to.include(
      `Role must be a string: 1`
    )

    const revokeNonStringRoleResult = await handle({
      From: nestId,
      Tags: [ { name: 'Action', value: 'Nest-Update' } ],
      Data: JSON.stringify({ Roles: { Revoke: { [BOB_ADDRESS]: [ 1 ] } } })
    })

    expect(revokeNonStringRoleResult.Error).to.exist
    expect(revokeNonStringRoleResult.Error).to.include(
      `Role must be a string: 1`
    )

    const grantNonListRolesResult = await handle({
      From: nestId,
      Tags: [ { name: 'Action', value: 'Nest-Update' } ],
      Data: JSON.stringify({ Roles: { Grant: { [BOB_ADDRESS]: 'admin' } } })
    })

    expect(grantNonListRolesResult.Error).to.exist
    expect(grantNonListRolesResult.Error).to.include(
      `Granted roles must be a list of strings`
    )

    const revokeNonListRolesResult = await handle({
      From: nestId,
      Tags: [ { name: 'Action', value: 'Nest-Update' } ],
      Data: JSON.stringify({ Roles: { Revoke: { [BOB_ADDRESS]: 'admin' } } })
    })

    expect(revokeNonListRolesResult.Error).to.exist
    expect(revokeNonListRolesResult.Error).to.include(
      `Revoked roles must be a list of strings`
    )
  })

  it('updates Roles on Nest-Update', async () => {
    const nestId = await makeNest()
    const messageId = 'message-id'.padEnd(43, '7')
    const result = await handle({
      Id: messageId,
      From: nestId,
      Tags: [ { name: 'Action', value: 'Nest-Update' } ],
      Data: JSON.stringify({ Roles: { Grant: { [BOB_ADDRESS]: [ 'admin' ] } } })
    })

    expect(result.Error).to.not.exist
    expect(result.Messages).to.have.lengthOf(1)
    expect(result.Messages[0].Data).to.equal('OK')
    expect(result.Messages[0].Tags).to.deep.include({
      name: 'Action',
      value: 'Nest-Update-Result'
    })
    expect(result.Messages[0].Tags).to.deep.include({
      name: 'Nest-Update-Message-Id',
      value: messageId
    })

    const viewStateResult = await handle({
      From: OWNER_ADDRESS,
      Tags: [ { name: 'Action', value: 'View-State' } ]
    })
    expect(viewStateResult.Error).to.not.exist
    expect(viewStateResult.Messages).to.have.lengthOf(1)
    expect(viewStateResult.Messages[0].Data).to.exist
    const state = JSON.parse(viewStateResult.Messages[0].Data)
    expect(state.WuzzyNests[nestId]).to.exist
    expect(state.WuzzyNests[nestId].Roles).to.deep.equal({
      admin: { [BOB_ADDRESS]: true }
    })
  })
})
