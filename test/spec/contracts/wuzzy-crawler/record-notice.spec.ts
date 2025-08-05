import { expect } from 'chai'

import {
  AOTestHandle,
  createLoader,
  MOCK_WEAVEDRIVE,
  OWNER_ADDRESS
} from '~/test/util/setup'
import MockTransaction from '~/test/util/mock-transaction.json'

describe('Wuzzy-Crawler Record-Notice Handlers', () => {
  let handle: AOTestHandle
  const NEST_ID = 'nestid_'.padEnd(43, '0')
  const ARIO_NETWORK_PROCESS_ID = 'ario_network_process_id_'.padEnd(43, '0')
  const ANT_PROCESS_ID = 'ant_process_id_'.padEnd(43, '0')

  beforeEach(async () => {
    const weaveDriveMock = MOCK_WEAVEDRIVE
      .replace(
        'local MOCK_WEAVEDRIVE_TXS = {}',
        `local MOCK_WEAVEDRIVE_TXS = { ` +
          `['${MockTransaction.tx.id}'] = '${JSON.stringify(MockTransaction.tx)}' ` +
        `}`
      )
      .replace(
        'local MOCK_WEAVEDRIVE_DATA = {}',
        `local MOCK_WEAVEDRIVE_DATA = { ` +
          `['${MockTransaction.tx.id}'] = '${JSON.stringify(MockTransaction.data)}' ` +
        `}`
      )
    handle = (await createLoader(
      'wuzzy-crawler', {
        processTags: [
          { name: 'Nest-Id', value: NEST_ID },
          { name: 'Ario-Network-Process-Id', value: ARIO_NETWORK_PROCESS_ID }
        ],
        weaveDriveMock
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

    // console.log(`DEBUG - AO EVAL Result `, JSON.stringify({
    //   Assignments: result.Assignments,
    //   Messages: result.Messages,
    //   Output: result.Output,
    //   Patches: result.Patches,
    //   Spawns: result.Spawns
    // }, null, 2))

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
        { name: 'Action', value: 'Record-Notice' },
        { name: 'Name', value: 'memeticblock' }
      ],
      Data: JSON.stringify({
        transactionId: MockTransaction.tx.id
      })
    })
    expect(result.Error).to.be.undefined
    expect(result.Messages).to.have.lengthOf(1)
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
      .to.include(`_MockWeaveDriveGetTxCalls: ${MockTransaction.tx.id}`)
  })
})
