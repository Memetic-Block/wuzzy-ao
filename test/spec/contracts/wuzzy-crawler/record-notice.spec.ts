import { expect } from 'chai'

import {
  ANT_PROCESS_ID,
  AOTestHandle,
  ARIO_NETWORK_PROCESS_ID,
  createLoader,
  NEST_ID,
  ORACLE_ADDRESS,
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
          { name: 'Ario-Network-Process-Id', value: ARIO_NETWORK_PROCESS_ID },
          { name: 'Data-Oracle-Address', value: ORACLE_ADDRESS }
        ]
      }
    )).handle
  })

  it('ignores Record-Notice messages from unknown sender', async () => {
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

  it('validates ARNS Record-Notice messages')
  it('ignores unexpected ARNS Record-Notice messages')

  it('requests ANT record when receiving ARNS Record-Notice', async () => {
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

  it('validates ANT Record-Notice messages')
  it('ignores unexpected ANT Record-Notice messages')

  it('requests tx info when receiving ANT Record-Notice', async () => {
    const requestCrawlResult = await handle({
      From: OWNER_ADDRESS,
      Tags: [
        { name: 'Action', value: 'Request-Crawl' },
        { name: 'URL', value: 'arns://memeticblock' }
      ]
    })
    expect(requestCrawlResult.Error).to.not.exist
    const recordNoticeResult = await handle({
      From: ARIO_NETWORK_PROCESS_ID,
      Tags: [
        { name: 'Action', value: 'Record-Notice' },
        { name: 'Name', value: 'memeticblock' }
      ],
      Data: JSON.stringify({
        processId: ANT_PROCESS_ID
      })
    })
    expect(recordNoticeResult.Error).to.not.exist
    const result = await handle({
      From: ANT_PROCESS_ID,
      Tags: [
        { name: 'Action', value: 'Record-Notice' }
      ],
      Data: JSON.stringify({
        transactionId: MockTransactions[0].tx.id
      })
    })
    expect(result.Error).to.not.exist
    expect(result.Messages).to.have.lengthOf(1)
    expect(result.Messages[0].Target).to.equal(ORACLE_ADDRESS)
    expect(result.Messages[0].Tags).to.deep.include({
      name: 'Action',
      value: 'Get-Transaction'
    })
    expect(result.Messages[0].Tags).to.deep.include({
      name: 'Transaction-Id',
      value: MockTransactions[0].tx.id
    })
  })

  it('finalizes crawl for already seen transactions', async () => {
    const protocol = 'arns'
    const name = 'memeticblock'
    const url = `${protocol}://${name}`
    const timestamp = Date.now().toString()

    await handle({
      From: OWNER_ADDRESS,
      Tags: [
        { name: 'Action', value: 'Request-Crawl' },
        { name: 'URL', value: url }
      ]
    })
    await handle({
      From: ARIO_NETWORK_PROCESS_ID,
      Tags: [
        { name: 'Action', value: 'Record-Notice' },
        { name: 'Name', value: name }
      ],
      Data: JSON.stringify({
        processId: ANT_PROCESS_ID
      })
    })
    await handle({
      From: ANT_PROCESS_ID,
      Tags: [
        { name: 'Action', value: 'Record-Notice' }
      ],
      Data: JSON.stringify({
        transactionId: MockTransactions[0].tx.id
      })
    })

    await handle({
      From: OWNER_ADDRESS,
      Tags: [
        { name: 'Action', value: 'Request-Crawl' },
        { name: 'URL', value: url }
      ]
    })
    await handle({
      From: ARIO_NETWORK_PROCESS_ID,
      Tags: [
        { name: 'Action', value: 'Record-Notice' },
        { name: 'Name', value: name }
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
      }),
      Timestamp: timestamp
    })

    expect(result.Error).to.not.exist
    expect(result.Messages).to.have.lengthOf(1)
    expect(result.Messages[0].Target).to.equal(NEST_ID)
    expect(result.Messages[0].Data).to.not.exist
    expect(result.Messages[0].Tags).to.deep.include({
      name: 'Action',
      value: 'Index-Document'
    })
    expect(result.Messages[0].Tags).to.deep.include({
      name: 'Document-Id',
      value: MockTransactions[0].tx.id
    })
    expect(result.Messages[0].Tags).to.deep.include({
      name: 'Document-Last-Crawled-At',
      value: timestamp
    })
    expect(result.Messages[0].Tags).to.deep.include({
      name: 'Document-Protocol',
      value: protocol
    })
    expect(result.Messages[0].Tags).to.deep.include({
      name: 'Document-URL',
      value: url
    })

    // Removed from AntRecordRequests
    const viewStateResult = await handle({
      From: OWNER_ADDRESS,
      Tags: [ { name: 'Action', value: 'View-State' } ]
    })
    expect(viewStateResult.Error).to.not.exist
    expect(viewStateResult.Messages).to.have.lengthOf(1)
    expect(viewStateResult.Messages[0].Data).to.exist
    const state = JSON.parse(viewStateResult.Messages[0].Data)
    expect(state.AntRecordRequests).to.be.an('array').that.is.empty
  })
})
