import { expect } from 'chai'

import {
  ANT_PROCESS_ID,
  AOTestHandle,
  ARIO_NETWORK_PROCESS_ID,
  createLoader,
  NEST_ID,
  OWNER_ADDRESS
} from '~/test/util/setup'
import MockTransactions from '~/test/util/mock-transactions.json'

describe('Wuzzy-Crawler Indexing', () => {
  let handle: AOTestHandle

  beforeEach(async () => {
    handle = (await createLoader(
      'wuzzy-crawler', {
        processTags: [
          { name: 'Nest-Id', value: NEST_ID },
          { name: 'Ario-Network-Process-Id', value: ARIO_NETWORK_PROCESS_ID }
        ],
        useWeaveDriveMock: true
      }
    )).handle
  })

  it('submits successful crawls for indexing', async () => {
    const arnsName = 'memeticblock'
    await handle({
      From: OWNER_ADDRESS,
      Tags: [
        { name: 'Action', value: 'Request-Crawl' },
        { name: 'URL', value: `arns://${arnsName}` }
      ]
    })
    await handle({
      From: ARIO_NETWORK_PROCESS_ID,
      Tags: [
        { name: 'Action', value: 'Record-Notice' },
        { name: 'Name', value: arnsName }
      ],
      Data: JSON.stringify({
        processId: ANT_PROCESS_ID
      })
    })
    const result = await handle({
      From: ANT_PROCESS_ID,
      Tags: [
        { name: 'Action', value: 'Record-Notice' },
        { name: 'Name', value: arnsName }
      ],
      Data: JSON.stringify({
        transactionId: MockTransactions[0].tx.id
      })
    })
    if (result.Error) {
      console.log(`DEBUG - AO Message Error: ${result.Error}`)
    }
    expect(result.Error).to.be.undefined
    expect(result.Messages).to.have.lengthOf(2)
    expect(result.Messages[0].Target).to.equal(OWNER_ADDRESS)
    expect(result.Messages[0].Tags).to.deep.include({
      name: 'Action',
      value: 'Crawl-Response'
    })
    expect(result.Messages[1].Target).to.equal(NEST_ID)
    expect(result.Messages[1].Tags).to.deep.include({
      name: 'Action',
      value: 'Index'
    })
    // ['Index-Type'] = 'ARNS',
    // ['Document-ARNS-Name'] = name,
    // ['Document-ARNS-Sub-Domain'] = '@', -- TODO -> Handle subdomains
    // ['Document-Content-Type'] = result.contentType,
    // ['Document-Transaction-Id'] = record.transactionId
    console.log('DEBUG - AO Message:', JSON.stringify(result.Messages, null, 2))
    expect(result.Messages[1].Tags).to.deep.include({
      name: 'Index-Type',
      value: 'ARNS'
    })
    expect(result.Messages[1].Tags).to.deep.include({
      name: 'Document-ARNS-Name',
      value: 'memeticblock'
    })
    expect(result.Messages[1].Data).to.exist
    expect(result.Messages[1].Data).to.equal(MockTransactions[0].data)
  })
})
