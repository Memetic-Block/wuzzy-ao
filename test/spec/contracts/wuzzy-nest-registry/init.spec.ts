import { expect } from 'chai'

import {
  AOTestHandle,
  createLoader,
  OWNER_ADDRESS,
  ARIO_NETWORK_PROCESS_ID,
  MODULE_ID
} from '~/test/util/setup'

describe('Wuzzy-Nest-Registry Initialization', () => {
  let handle: AOTestHandle

  beforeEach(async () => {
    handle = (await createLoader('wuzzy-nest-registry')).handle
  })

  it('initializes and responds to View-State with init values', async () => {
    const result = await handle({
      From: OWNER_ADDRESS,
      Tags: [
        { name: 'Action', value: 'View-State' }
      ]
    })

    expect(result.Messages).to.have.lengthOf(1)
    expect(result.Messages[0].Data).to.exist
    const data = JSON.parse(result.Messages[0].Data)
    expect(data).to.have.property('WuzzyNestModuleId', MODULE_ID)
  })
})
