import { expect } from 'chai'
import { readFileSync } from 'fs'
import path from 'path'

import {
  ANT_PROCESS_ID,
  AOTestHandle,
  ARIO_NETWORK_PROCESS_ID,
  createLoader,
  NEST_ID,
  ORACLE_ADDRESS,
  OWNER_ADDRESS
} from '~/test/util/setup'
import CookbookAOManifest from '~/test/util/cookbook_ao-manifest.json'

describe('Wuzzy-Crawler Parsing', () => {
  let handle: AOTestHandle

  beforeEach(async () => {
    handle = (await createLoader(
      'wuzzy-crawler', {
        processTags: [
          { name: 'Nest-Id', value: NEST_ID },
          { name: 'Ario-Network-Process-Id', value: ARIO_NETWORK_PROCESS_ID },
          { name: 'Data-Oracle-Address', value: ORACLE_ADDRESS}
        ]
      }
    )).handle
  })

  const sendGetDataResult = async (
    opts: {
      protocol: 'arns',
      name: string,
      transactionId: string,
      tx: any,
      data: any,
      timestamp: string
  }) => {
    const { protocol, name, transactionId, tx, data, timestamp } = opts
    const url = `${protocol}://${name}`
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
        { name: 'Name', value: opts.name }
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
      Data: JSON.stringify({ transactionId })
    })
    await handle({
      From: ORACLE_ADDRESS,
      Tags: [
        { name: 'Action', value: 'Get-Transaction-Result' },
        { name: 'Transaction-Id', value: transactionId }
      ],
      Data: JSON.stringify(tx)
    })

    return handle({
      From: ORACLE_ADDRESS,
      Tags: [
        { name: 'Action', value: 'Get-Data-Result' },
        { name: 'Transaction-Id', value: transactionId }
      ],
      Data: data,
      Timestamp: timestamp
    })
  }

  describe('HTML', () => {
    it('parses HTML', async () => {
      const protocol = 'arns'
      const name = 'memeticblock'
      const url = `${protocol}://${name}`
      const transactionId = 'memeticblock'.padEnd(43, 'm')
      const content = readFileSync(
        path.join(path.resolve(), `./test/util/memeticblock.com.html`),
        'utf-8'
      )
      const timestamp = Date.now().toString()
      const result = await sendGetDataResult({
        protocol,
        name,
        transactionId,
        tx: {
          id: transactionId,
          tags: [ { name: 'Content-Type', value: 'text/html' } ]
        },
        data: content,
        timestamp
      })
      expect(result.Error).to.not.exist
      expect(result.Messages).to.have.lengthOf(1)
      expect(result.Messages[0].Target).to.equal(NEST_ID)
      expect(result.Messages[0].Tags).to.deep.include({
        name: 'Document-Id',
        value: transactionId
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
      expect(result.Messages[0].Tags).to.deep.include({
        name: 'Document-Content-Type',
        value: 'text/html'
      })
      expect(result.Messages[0].Data).to.exist
      // console.log('parsed', result.Messages[0].Data)
      // console.log('output', result.Output)
    })
  })

  describe('Arweave Manifests', () => {
    it('does not recursively parse manifests')

    it('requests tx for each path & skips unsupported mime types', async () => {
      const protocol = 'arns'
      const name = 'cookbook_ao'
      const transactionId = 'cookbook_ao'.padEnd(43, 'm')
      const content = JSON.stringify(CookbookAOManifest)
      const manifestPaths =
        CookbookAOManifest.paths as unknown as Record<string, { id: string }>
      const pathTransactionIds = Object.keys(manifestPaths)
        .filter(path => path.endsWith('.txt') || path.endsWith('.html'))
        .map(path => manifestPaths[path].id)
        .sort()
      const timestamp = Date.now().toString()
      const result = await sendGetDataResult({
        protocol,
        name,
        transactionId,
        tx: {
          id: transactionId,
          tags: [
            {
              name: 'Content-Type',
              value: 'application/x.arweave-manifest+json'
            }
          ]
        },
        data: content,
        timestamp
      })
      expect(result.Error).to.not.exist
      expect(result.Messages).to.have.lengthOf(pathTransactionIds.length)
      expect(
        result.Messages.every(msg => msg.Target === ORACLE_ADDRESS)
      ).to.be.true
      expect(
        result.Messages.every(
          msg => msg.Tags.some(
            tag => tag.name === 'Action' && tag.value === 'Get-Transaction'
          )
        )
      ).to.be.true
      const requestedTransactionIds = result.Messages.map(
        msg => msg.Tags.find(tag => tag.name === 'Transaction-Id')?.value
      )
      expect(requestedTransactionIds.sort()).to.deep.equal(pathTransactionIds)
    })
  })
})
