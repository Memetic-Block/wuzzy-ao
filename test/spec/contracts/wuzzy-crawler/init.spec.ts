import { expect } from 'chai'

import {
  AOTestHandle,
  ARIO_NETWORK_PROCESS_ID,
  createLoader,
  NEST_ID,
  ORACLE_ADDRESS,
  OWNER_ADDRESS
} from '~/test/util/setup'

describe('Wuzzy-Crawler Initialization', () => {
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

  it('should initialize with the correct Nest ID', async () => {
    const result = await handle({
      From: OWNER_ADDRESS,
      Tags: [
        { name: 'Action', value: 'View-State' }
      ]
    })
    expect(result.Error).to.not.exist
    expect(result.Messages).to.have.lengthOf(1)
    expect(result.Messages[0].Data).to.exist
    const data = JSON.parse(result.Messages[0].Data)
    expect(data).to.have.property('NestId')
    expect(data['NestId']).to.include(NEST_ID)
  })
})
