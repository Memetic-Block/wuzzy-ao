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

describe('Wuzzy-Crawler Record-Notice', () => {
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

  it('validates record-notice requests')

  it('ignores unknown crawl requests', async () => {
    const result = await handle({
      From: OWNER_ADDRESS,
      Tags: [
        { name: 'Action', value: 'Record-Notice' },
        { name: 'Name', value: 'testname' }
      ]
    })

    expect(result.Error).to.be.undefined
    expect(result.Messages).to.have.lengthOf(0)
  })

  it('validates ARNS record notices')

  it('requests ANT record when receiving ARNS record notice', async () => {
    await handle({
      From: OWNER_ADDRESS,
      Tags: [
        { name: 'Action', value: 'Request-Crawl' },
        { name: 'URL', value: 'arns://memeticblock' }
      ]
    })
    const result = await handle({
      From: ARIO_NETWORK_PROCESS_ID,
      Tags: [
        { name: 'Action', value: 'Record-Notice' },
        { name: 'Name', value: 'memeticblock' }
      ],
      Data: JSON.stringify({
        processId: ANT_PROCESS_ID
      })
    })

    expect(result.Error).to.be.undefined
    expect(result.Messages).to.have.lengthOf(1)
    expect(result.Messages[0].Target).to.equal(ANT_PROCESS_ID)
    expect(result.Messages[0].Tags).to.deep.include({
      name: 'Action',
      value: 'Record'
    })
    expect(result.Messages[0].Tags).to.deep.include({
      name: 'Sub-Domain',
      value: '@'
    })
  })

  it('validates ANT record notices')

  it('requests transaction when receiving ANT record notice', async () => {
    await handle({
      From: OWNER_ADDRESS,
      Tags: [
        { name: 'Action', value: 'Request-Crawl' },
        { name: 'URL', value: 'arns://memeticblock' }
      ]
    })
    await handle({
      From: ARIO_NETWORK_PROCESS_ID,
      Tags: [
        { name: 'Action', value: 'Record-Notice' },
        { name: 'Name', value: 'memeticblock' }
      ],
      Data: JSON.stringify({
        processId: ANT_PROCESS_ID
      })
    })
    const result = await handle({
      From: ANT_PROCESS_ID,
      Tags: [
        { name: 'Action', value: 'Record-Notice' }
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

    const checkWeaveDriveMockResult = await handle({
      From: OWNER_ADDRESS,
      Tags: [
        { name: 'Action', value: 'Eval' }
      ],
      Data: 'print("_MockWeaveDriveGetTxCalls: ".._MockWeaveDriveGetTxCalls[1])'
    })
    expect(checkWeaveDriveMockResult.Output?.data).to.exist
    expect(checkWeaveDriveMockResult.Output?.data)
      .to.include(`_MockWeaveDriveGetTxCalls: ${MockTransactions[0].tx.id}`)
  })
})
