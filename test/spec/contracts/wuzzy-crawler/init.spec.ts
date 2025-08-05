import { expect } from 'chai'

import {
  AOTestHandle,
  createLoader,
  OWNER_ADDRESS,
  MOCK_WEAVEDRIVE
} from '~/test/util/setup'

describe('Wuzzy-Crawler Initialization', () => {
  let handle: AOTestHandle
  const NEST_ID = 'nestid_'.padEnd(43, '0')

  beforeEach(async () => {
    handle = (await createLoader(
      'wuzzy-crawler', {
        processTags: [ { name: 'Nest-Id', value: NEST_ID } ],
        weaveDriveMock: MOCK_WEAVEDRIVE
      }
    )).handle
  })

  it('should initialize with the correct Nest ID', async () => {
    const result = await handle({
      From: OWNER_ADDRESS,
      Tags: [
        { name: 'Action', value: 'View-State' }
      ]
    })

    expect(result.Messages).to.have.lengthOf(1)
    expect(result.Messages[0].Data).to.exist
    const data = JSON.parse(result.Messages[0].Data)
    expect(data).to.have.property('NestId')
    expect(data['NestId']).to.include(NEST_ID)
  })
})
