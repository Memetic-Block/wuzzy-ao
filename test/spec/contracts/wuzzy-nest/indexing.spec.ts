import { expect } from 'chai'

import {
  AOTestHandle,
  createLoader,
  OWNER_ADDRESS
} from '~/test/util/setup'

describe('Wuzzy-Nest Indexing', () => {
  let handle: AOTestHandle

  beforeEach(async () => {
    handle = (await createLoader('wuzzy-nest')).handle
  })

  it('accepts Index messages & track Documents', async () => {
    const crawlerAddress = 'CRAWLER_ADDRESS'
    const indexType = 'ARNS'
    const arnsName = 'memeticblock'
    const arnsSubdomain = '@'
    const contentType = 'text/plain'
    const transactionId = '12345'
    const content = 'This is a test document.'
    const result = await handle({
      From: crawlerAddress,
      Tags: [
        { name: 'Action', value: 'Index' },
        { name: 'Index-Type', value: indexType },
        { name: 'Document-ARNS-Name', value: arnsName },
        { name: 'Document-ARNS-Sub-Domain', value: arnsSubdomain },
        { name: 'Document-Content-Type', value: contentType },
        { name: 'Document-Transaction-Id', value: transactionId }
      ],
      Data: content
    })
    if (result.Error) {
      console.log(`DEBUG - AO Message Error: ${result.Error}`)
    }
    expect(result.Error).to.not.exist
    expect(result.Messages).to.have.lengthOf(1)
    expect(result.Messages[0].Data).to.exist
    expect(result.Messages[0].Data).to.equal('OK')
    expect(result.Messages[0].Tags).to.deep.include({
      name: 'Action',
      value: 'Index-Response'
    })

    const viewStateResult = await handle({
      From: OWNER_ADDRESS,
      Tags: [{ name: 'Action', value: 'View-State' }]
    })
    expect(viewStateResult.Error).to.not.exist
    expect(viewStateResult.Messages).to.have.lengthOf(1)
    expect(viewStateResult.Messages[0].Data).to.exist
    const state = JSON.parse(viewStateResult.Messages[0].Data)
    expect(state.Documents).to.be.an('array')
    expect(state.Documents).to.have.lengthOf(1)
    expect(state.Documents[0]).to.deep.include({
      SubmittedBy: crawlerAddress,
      TransactionId: transactionId,
      IndexType: indexType,
      ARNSName: arnsName,
      ARNSSubDomain: arnsSubdomain,
      ContentType: contentType,
      Content: content
    })
  })

  it('ignores Index messages from unknown sources')

  it('rejects bad or incomplete Index messages')
})
