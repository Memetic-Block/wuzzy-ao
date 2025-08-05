import { expect } from 'chai'

import {
  AOTestHandle,
  createLoader,
  OWNER_ADDRESS
} from '~/test/util/setup'

describe('Wuzzy-Nest Initialization', () => {
  let handle: AOTestHandle

  beforeEach(async () => {
    handle = (await createLoader('wuzzy-nest')).handle
  })

  it('should initialize and respond to View-State', async () => {
    const result = await handle({
      From: OWNER_ADDRESS,
      Tags: [
        { name: 'Action', value: 'View-State' }
      ]
    })

    expect(result.Messages).to.have.lengthOf(1)
    expect(result.Messages[0].Data).to.exist
  })
})
