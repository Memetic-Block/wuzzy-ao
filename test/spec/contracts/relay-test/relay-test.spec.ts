import { expect } from 'chai'

import {
  AOTestHandle,
  createLoader,
  OWNER_ADDRESS
} from '~/test/util/setup'

describe('Relay-Test Initialization', () => {
  let handle: AOTestHandle

  beforeEach(async () => {
    handle = (await createLoader('relay-test')).handle
  })

  it('should initialize and respond GET', async () => {
    const result = await handle({
      From: OWNER_ADDRESS,
      Tags: [
        { name: 'Action', value: 'GET' },
        { name: 'URL', value: 'https://arweave.net' }
      ]
    })
    console.log(
      'relay-test GET result',
      JSON.stringify({ ...result, Memory: '' }, null, 2)
    )
    expect(result.Messages).to.have.lengthOf(1)
    expect(result.Messages[0].Data).to.exist
  })
})
