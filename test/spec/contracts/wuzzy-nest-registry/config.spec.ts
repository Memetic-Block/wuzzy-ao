import { expect } from 'chai'

import {
  ALICE_ADDRESS,
  AOTestHandle,
  createLoader,
  OWNER_ADDRESS
} from '~/test/util/setup'

describe('Wuzzy-Nest-Registry Configuration', () => {
  let handle: AOTestHandle
  const wuzzyNestModuleId = 'wuzzy-nest-module'.padEnd(43, '0')

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

  describe('Wuzzy-Nest-Module-Id', () => {
    it('allows owner to set Wuzzy-Nest-Module-Id', async () => {
      const newWuzzyNestModuleId = 'new-wuzzy-nest-module'.padEnd(43, '0')
      const result = await handle({
        From: OWNER_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Set-Wuzzy-Nest-Module-Id' },
          { name: 'Wuzzy-Nest-Module-Id', value: newWuzzyNestModuleId }
        ]
      })

      expect(result.Messages).to.have.lengthOf(1)
      expect(result.Messages[0].Data).to.exist
      expect(result.Messages[0].Data).to.equal('OK')
      expect(result.Messages[0].Tags).to.deep.include({
        name: 'Action',
        value: 'Set-Wuzzy-Nest-Module-Id-Result'
      })
      expect(result.Messages[0].Tags).to.deep.include({
        name: 'Wuzzy-Nest-Module-Id',
        value: newWuzzyNestModuleId
      })
      const viewStateResult = await handle({
        From: OWNER_ADDRESS,
        Tags: [ { name: 'Action', value: 'View-State' } ]
      })
      expect(viewStateResult.Messages).to.have.lengthOf(1)
      expect(viewStateResult.Messages[0].Data).to.exist
      const state = JSON.parse(viewStateResult.Messages[0].Data)
      expect(state.WuzzyNestModuleId).to.equal(newWuzzyNestModuleId)
    })

    it('allows admins to set Wuzzy-Nest-Module-Id', async () => {
      const newWuzzyNestModuleId = 'new-wuzzy-nest-module'.padEnd(43, '0')
      await handle({
        From: OWNER_ADDRESS,
        Tags: [ { name: 'Action', value: 'Update-Roles' } ],
        Data: JSON.stringify({
          Grant: {
            [ALICE_ADDRESS]: [ 'admin' ]
          }
        })
      })

      const result = await handle({
        From: ALICE_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Set-Wuzzy-Nest-Module-Id' },
          { name: 'Wuzzy-Nest-Module-Id', value: newWuzzyNestModuleId }
        ]
      })

      expect(result.Messages).to.have.lengthOf(1)
      expect(result.Messages[0].Data).to.exist
      expect(result.Messages[0].Data).to.equal('OK')
      expect(result.Messages[0].Tags).to.deep.include({
        name: 'Action',
        value: 'Set-Wuzzy-Nest-Module-Id-Result'
      })
      expect(result.Messages[0].Tags).to.deep.include({
        name: 'Wuzzy-Nest-Module-Id',
        value: newWuzzyNestModuleId
      })
      const viewStateResult = await handle({
        From: OWNER_ADDRESS,
        Tags: [ { name: 'Action', value: 'View-State' } ]
      })
      expect(viewStateResult.Messages).to.have.lengthOf(1)
      expect(viewStateResult.Messages[0].Data).to.exist
      const state = JSON.parse(viewStateResult.Messages[0].Data)
      expect(state.WuzzyNestModuleId).to.equal(newWuzzyNestModuleId)
    })

    it('allows ACL permissioned users to set Wuzzy-Nest-Module-Id', async () => {
      const newWuzzyNestModuleId = 'new-wuzzy-nest-module'.padEnd(43, '0')
      await handle({
        From: OWNER_ADDRESS,
        Tags: [ { name: 'Action', value: 'Update-Roles' } ],
        Data: JSON.stringify({
          Grant: {
            [ALICE_ADDRESS]: [ 'Set-Wuzzy-Nest-Module-Id' ]
          }
        })
      })

      const result = await handle({
        From: ALICE_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Set-Wuzzy-Nest-Module-Id' },
          { name: 'Wuzzy-Nest-Module-Id', value: newWuzzyNestModuleId }
        ]
      })

      expect(result.Messages).to.have.lengthOf(1)
      expect(result.Messages[0].Data).to.exist
      expect(result.Messages[0].Data).to.equal('OK')
      expect(result.Messages[0].Tags).to.deep.include({
        name: 'Action',
        value: 'Set-Wuzzy-Nest-Module-Id-Result'
      })
      expect(result.Messages[0].Tags).to.deep.include({
        name: 'Wuzzy-Nest-Module-Id',
        value: newWuzzyNestModuleId
      })
      const viewStateResult = await handle({
        From: OWNER_ADDRESS,
        Tags: [ { name: 'Action', value: 'View-State' } ]
      })
      expect(viewStateResult.Messages).to.have.lengthOf(1)
      expect(viewStateResult.Messages[0].Data).to.exist
      const state = JSON.parse(viewStateResult.Messages[0].Data)
      expect(state.WuzzyNestModuleId).to.equal(newWuzzyNestModuleId)
    })

    it('prevents anyone else from setting Wuzzy-Nest-Module-Id', async () => {
      const newWuzzyNestModuleId = 'new-wuzzy-nest-module'.padEnd(43, '0')
      const result = await handle({
        From: ALICE_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Set-Wuzzy-Nest-Module-Id' },
          { name: 'Wuzzy-Nest-Module-Id', value: newWuzzyNestModuleId }
        ]
      })

      expect(result.Error).to.exist
      expect(result.Error).to.include('Permission Denied')
    })

    it('requires Wuzzy-Nest-Module-Id', async () => {
      const result = await handle({
        From: OWNER_ADDRESS,
        Tags: [ { name: 'Action', value: 'Set-Wuzzy-Nest-Module-Id' } ]
      })

      expect(result.Error).to.exist
      expect(result.Error).to.include('Wuzzy-Nest-Module-Id is required')
    })
  })
})
