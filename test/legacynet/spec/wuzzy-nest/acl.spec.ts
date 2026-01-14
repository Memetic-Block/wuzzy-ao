import { expect } from 'chai'

import {
  ALICE_ADDRESS,
  AOTestHandle,
  BOB_ADDRESS,
  createLoader,
  OWNER_ADDRESS
} from '../../util/setup'

describe('ACL - wuzzy-nest (legacynet)', () => {
  let handle: AOTestHandle

  beforeEach(async () => {
    handle = (await createLoader('wuzzy-nest')).handle
  })

  describe('Granting/Revoking Roles', () => {
    it('Allows Owner to grant roles', async () => {
      const grantResult = await handle({
        From: OWNER_ADDRESS,
        Tags: [{ name: 'Action', value: 'Update-Roles' }],
        Data: JSON.stringify({
          Grant: { [ALICE_ADDRESS]: ['admin', 'Index-Document'] }
        })
      })

      expect(grantResult.Messages).to.have.lengthOf(1)
      expect(grantResult.Messages[0].Data).to.equal('OK')

      // Verify roles were granted by viewing them
      const viewResult = await handle({
        From: BOB_ADDRESS,
        Tags: [{ name: 'Action', value: 'View-Roles' }]
      })

      expect(viewResult.Messages).to.have.lengthOf(1)
      const roles = JSON.parse(viewResult.Messages[0].Data)
      expect(roles.roles.admin[ALICE_ADDRESS]).to.be.true
      expect(roles.roles['Index-Document'][ALICE_ADDRESS]).to.be.true
    })

    it('Allows Owner to revoke roles', async () => {
      // First grant roles
      await handle({
        From: OWNER_ADDRESS,
        Tags: [{ name: 'Action', value: 'Update-Roles' }],
        Data: JSON.stringify({
          Grant: { [ALICE_ADDRESS]: ['admin'] }
        })
      })

      // Then revoke them
      const revokeResult = await handle({
        From: OWNER_ADDRESS,
        Tags: [{ name: 'Action', value: 'Update-Roles' }],
        Data: JSON.stringify({
          Revoke: { [ALICE_ADDRESS]: ['admin'] }
        })
      })

      expect(revokeResult.Messages).to.have.lengthOf(1)
      expect(revokeResult.Messages[0].Data).to.equal('OK')
    })

    it('Denies non-owner from granting roles', async () => {
      const result = await handle({
        From: ALICE_ADDRESS,
        Tags: [{ name: 'Action', value: 'Update-Roles' }],
        Data: JSON.stringify({
          Grant: { [BOB_ADDRESS]: ['admin'] }
        })
      })

      expect(result.Error).to.be.a('string').that.includes('Permission Denied')
    })

    it('Allows admin to grant roles', async () => {
      // Grant admin role to ALICE first
      await handle({
        From: OWNER_ADDRESS,
        Tags: [{ name: 'Action', value: 'Update-Roles' }],
        Data: JSON.stringify({
          Grant: { [ALICE_ADDRESS]: ['admin'] }
        })
      })

      // ALICE should now be able to grant roles
      const result = await handle({
        From: ALICE_ADDRESS,
        Tags: [{ name: 'Action', value: 'Update-Roles' }],
        Data: JSON.stringify({
          Grant: { [BOB_ADDRESS]: ['Index-Document'] }
        })
      })

      expect(result.Messages).to.have.lengthOf(1)
      expect(result.Messages[0].Data).to.equal('OK')
    })
  })
})
