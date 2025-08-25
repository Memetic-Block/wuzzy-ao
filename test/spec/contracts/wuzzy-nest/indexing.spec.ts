import { expect } from 'chai'

import {
  ALICE_ADDRESS,
  AOTestHandle,
  BOB_ADDRESS,
  createLoader,
  OWNER_ADDRESS
} from '~/test/util/setup'

describe('Wuzzy-Nest Indexing', () => {
  let handle: AOTestHandle

  beforeEach(async () => {
    handle = (await createLoader('wuzzy-nest')).handle
  })

  it('accepts Index-Document messages & track Documents', async () => {
    const crawlerAddress = 'CRAWLER_ADDRESS'.padEnd(43, 'c')
    await handle({
      From: OWNER_ADDRESS,
      Tags: [
        { name: 'Action', value: 'Update-Roles' }
      ],
      Data: JSON.stringify({
        Grant: { [crawlerAddress]: [ 'Index-Document' ] }
      })
    })

    const indexType = 'ARNS'
    const arnsName = 'memeticblock'
    const arnsSubdomain = '@'
    const contentType = 'text/plain'
    const transactionId = '12345'
    const content = 'This is a test document.'
    const result = await handle({
      From: crawlerAddress,
      Tags: [
        { name: 'Action', value: 'Index-Document' },
        { name: 'Index-Type', value: indexType },
        { name: 'Document-ARNS-Name', value: arnsName },
        { name: 'Document-ARNS-Sub-Domain', value: arnsSubdomain },
        { name: 'Document-Content-Type', value: contentType },
        { name: 'Document-Id', value: transactionId }
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
      value: 'Index-Document-Result'
    })

    const secondArnsName = 'arns://wuzzy'
    const secondDocumentId = '45678'
    const result2 = await handle({
      From: crawlerAddress,
      Tags: [
        { name: 'Action', value: 'Index-Document' },
        { name: 'Index-Type', value: indexType },
        { name: 'Document-ARNS-Name', value: secondArnsName },
        { name: 'Document-ARNS-Sub-Domain', value: arnsSubdomain },
        { name: 'Document-Content-Type', value: contentType },
        { name: 'Document-Id', value: secondDocumentId }
      ],
      Data: content
    })
    if (result2.Error) {
      console.log(`DEBUG - AO Message Error: ${result2.Error}`)
    }
    expect(result2.Error).to.not.exist
    expect(result2.Messages).to.have.lengthOf(1)
    expect(result2.Messages[0].Data).to.exist
    expect(result2.Messages[0].Data).to.equal('OK')
    expect(result2.Messages[0].Tags).to.deep.include({
      name: 'Action',
      value: 'Index-Document-Result'
    })

    const viewStateResult = await handle({
      From: OWNER_ADDRESS,
      Tags: [{ name: 'Action', value: 'View-State' }]
    })
    expect(viewStateResult.Error).to.not.exist
    expect(viewStateResult.Messages).to.have.lengthOf(1)
    expect(viewStateResult.Messages[0].Data).to.exist
    const state = JSON.parse(viewStateResult.Messages[0].Data)
    expect(state.Documents).to.be.an('object')
    expect(Object.keys(state.Documents)).to.have.lengthOf(2)
    expect(state.Documents[transactionId]).to.deep.include({
      SubmittedBy: crawlerAddress,
      DocumentId: transactionId,
      IndexType: indexType,
      ARNSName: arnsName,
      ARNSSubDomain: arnsSubdomain,
      ContentType: contentType,
      Content: content
    })
    expect(state.Documents[secondDocumentId]).to.deep.include({
      SubmittedBy: crawlerAddress,
      DocumentId: secondDocumentId,
      IndexType: indexType,
      ARNSName: secondArnsName,
      ARNSSubDomain: arnsSubdomain,
      ContentType: contentType,
      Content: content
    })
    expect(state.TotalTermCount).to.equal(content.length * 2)
    expect(state.AverageDocumentTermLength).to.equal(content.length)
    expect(state.TotalDocuments).to.equal(2)
  })

  it('ignores Index messages from unknown sources', async () => {
    const indexType = 'ARNS'
    const arnsName = 'memeticblock'
    const arnsSubdomain = '@'
    const contentType = 'text/plain'
    const transactionId = '12345'
    const content = 'This is a test document.'
    const result = await handle({
      From: ALICE_ADDRESS,
      Tags: [
        { name: 'Action', value: 'Index-Document' },
        { name: 'Index-Type', value: indexType },
        { name: 'Document-ARNS-Name', value: arnsName },
        { name: 'Document-ARNS-Sub-Domain', value: arnsSubdomain },
        { name: 'Document-Content-Type', value: contentType },
        { name: 'Document-Id', value: transactionId }
      ],
      Data: content
    })

    expect(result.Error).to.exist
    expect(result.Error).to.include('Permission Denied')
  })

  describe('Validation', () => {
    const crawlerAddress = 'CRAWLER_ADDRESS'.padEnd(43, 'c')
    beforeEach(async () => {
      await handle({
        From: OWNER_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Update-Roles' }
        ],
        Data: JSON.stringify({
          Grant: { [crawlerAddress]: [ 'Index-Document' ] }
        })
      })
    })

    it('throws on invalid Index-Type', async () => {
      const result = await handle({
        From: crawlerAddress,
        Tags: [{ name: 'Action', value: 'Index-Document' }]
      })

      expect(result.Error).to.exist
      expect(result.Error).to.include('Wrong Index-Type')
    })

    it('throws on missing Document-ARNS-Name', async () => {
      const result = await handle({
        From: crawlerAddress,
        Tags: [
          { name: 'Action', value: 'Index-Document' },
          { name: 'Index-Type', value: 'ARNS' }
        ]
      })

      expect(result.Error).to.exist
      expect(result.Error).to.include('Missing Document-ARNS-Name')
    })

    it('throws on missing Document-ARNS-Sub-Domain', async () => {
      const result = await handle({
        From: crawlerAddress,
        Tags: [
          { name: 'Action', value: 'Index-Document' },
          { name: 'Index-Type', value: 'ARNS' },
          { name: 'Document-ARNS-Name', value: 'memeticblock' }
        ]
      })

      expect(result.Error).to.exist
      expect(result.Error).to.include('Missing Document-ARNS-Sub-Domain')
    })

    it('throws on missing Document-Content-Type', async () => {
      const result = await handle({
        From: crawlerAddress,
        Tags: [
          { name: 'Action', value: 'Index-Document' },
          { name: 'Index-Type', value: 'ARNS' },
          { name: 'Document-ARNS-Name', value: 'memeticblock' },
          { name: 'Document-ARNS-Sub-Domain', value: '@' }
        ]
      })

      expect(result.Error).to.exist
      expect(result.Error).to.include('Missing Document-Content-Type')
    })

    it('throws on missing Document-Id', async () => {
      const result = await handle({
        From: crawlerAddress,
        Tags: [
          { name: 'Action', value: 'Index-Document' },
          { name: 'Index-Type', value: 'ARNS' },
          { name: 'Document-ARNS-Name', value: 'memeticblock' },
          { name: 'Document-ARNS-Sub-Domain', value: '@' },
          { name: 'Document-Content-Type', value: 'text/plain' }
        ]
      })

      expect(result.Error).to.exist
      expect(result.Error).to.include('Missing Document-Id')
    })

    it('throws on missing Document Content', async () => {
      const result = await handle({
        From: crawlerAddress,
        Tags: [
          { name: 'Action', value: 'Index-Document' },
          { name: 'Index-Type', value: 'ARNS' },
          { name: 'Document-ARNS-Name', value: 'memeticblock' },
          { name: 'Document-ARNS-Sub-Domain', value: '@' },
          { name: 'Document-Content-Type', value: 'text/plain' },
          { name: 'Document-Id', value: '12345'.padEnd(43, 'x') }
        ]
      })

      expect(result.Error).to.exist
      expect(result.Error).to.include('Missing Document Content')
    })
  })

  describe('Removing Documents', () => {
    it('requires Document-Id to remove a document', async () => {
      const result = await handle({
        From: OWNER_ADDRESS,
        Tags: [ { name: 'Action', value: 'Remove-Document' } ]
      })

      expect(result.Error).to.exist
      expect(result.Error).to.include('Document-Id is required')
    })

    it('throws if document does not exist', async () => {
      const result = await handle({
        From: OWNER_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Remove-Document' },
          { name: 'Document-Id', value: 'missing-document' }
        ]
      })

      expect(result.Error).to.exist
      expect(result.Error).to.include('Document not found')
    })

    it('prevents unknown callers from removing documents', async () => {
      const result = await handle({
        From: ALICE_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Remove-Document' },
          { name: 'Document-Id', value: 'missing-document' }
        ]
      })

      expect(result.Error).to.exist
      expect(result.Error).to.include('Permission Denied')
    })

    it('allows owner, admin, or ACL to remove documents', async () => {
      const documents = [
        { id: '12345', content: 'This is a test document' },
        { id: '67890', content: 'This is a test document' },
        { id: '22345', content: 'This is a test document' }
      ]
      for (const { id, content } of documents) {
        await handle({
          From: OWNER_ADDRESS,
          Tags: [
            { name: 'Action', value: 'Index-Document' },
            { name: 'Index-Type', value: 'ARNS' },
            { name: 'Document-ARNS-Name', value: 'memeticblock' },
            { name: 'Document-ARNS-Sub-Domain', value: '@' },
            { name: 'Document-Content-Type', value: 'text/plain' },
            { name: 'Document-Id', value: id }
          ],
          Data: content
        })
      }

      const ownerResult = await handle({
        From: OWNER_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Remove-Document' },
          { name: 'Document-Id', value: documents[0].id }
        ]
      })
      expect(ownerResult.Error).to.not.exist
      expect(ownerResult.Messages).to.have.lengthOf(1)
      expect(ownerResult.Messages[0].Tags).to.deep.include({
        name: 'Action',
        value: 'Remove-Document-Result'
      })
      expect(ownerResult.Messages[0].Tags).to.deep.include({
        name: 'Document-Id',
        value: documents[0].id
      })
      expect(ownerResult.Messages[0].Data).to.equal('OK')
      const ownerViewStateResult = await handle({
        From: OWNER_ADDRESS,
        Tags: [{ name: 'Action', value: 'View-State' }]
      })
      expect(ownerViewStateResult.Messages).to.have.lengthOf(1)
      expect(ownerViewStateResult.Messages[0].Data).to.exist
      const ownerState = JSON.parse(ownerViewStateResult.Messages[0].Data)      
      expect(Object.keys(ownerState.Documents)).to.have.lengthOf(2)
      expect(ownerState.TotalDocuments).to.equal(2)

      await handle({
        From: OWNER_ADDRESS,
        Tags: [{ name: 'Action', value: 'Update-Roles'}],
        Data: JSON.stringify({ Grant: { [ALICE_ADDRESS]: [ 'admin' ] } })
      })
      const adminResult = await handle({
        From: ALICE_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Remove-Document' },
          { name: 'Document-Id', value: documents[1].id }
        ]
      })
      expect(adminResult.Error).to.not.exist
      expect(adminResult.Messages).to.have.lengthOf(1)
      expect(adminResult.Messages[0].Tags).to.deep.include({
        name: 'Action',
        value: 'Remove-Document-Result'
      })
      expect(adminResult.Messages[0].Tags).to.deep.include({
        name: 'Document-Id',
        value: documents[1].id
      })
      expect(adminResult.Messages[0].Data).to.equal('OK')
      const adminViewStateResult = await handle({
        From: ALICE_ADDRESS,
        Tags: [{ name: 'Action', value: 'View-State' }]
      })
      expect(adminViewStateResult.Messages).to.have.lengthOf(1)
      expect(adminViewStateResult.Messages[0].Data).to.exist
      const adminState = JSON.parse(adminViewStateResult.Messages[0].Data)
      expect(Object.keys(adminState.Documents)).to.have.lengthOf(1)
      expect(adminState.TotalDocuments).to.equal(1)

      await handle({
        From: OWNER_ADDRESS,
        Tags: [{ name: 'Action', value: 'Update-Roles'}],
        Data: JSON.stringify({
          Grant: { [BOB_ADDRESS]: [ 'Remove-Document' ] }
        })
      })
      const aclResult = await handle({
        From: BOB_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Remove-Document' },
          { name: 'Document-Id', value: documents[2].id }
        ]
      })
      expect(aclResult.Error).to.not.exist
      expect(aclResult.Messages).to.have.lengthOf(1)
      expect(aclResult.Messages[0].Tags).to.deep.include({
        name: 'Action',
        value: 'Remove-Document-Result'
      })
      expect(aclResult.Messages[0].Tags).to.deep.include({
        name: 'Document-Id',
        value: documents[2].id
      })
      expect(aclResult.Messages[0].Data).to.equal('OK')
      const aclViewStateResult = await handle({
        From: BOB_ADDRESS,
        Tags: [{ name: 'Action', value: 'View-State' }]
      })
      expect(aclViewStateResult.Messages).to.have.lengthOf(1)
      expect(aclViewStateResult.Messages[0].Data).to.exist
      const aclState = JSON.parse(aclViewStateResult.Messages[0].Data)
      expect(Object.keys(aclState.Documents)).to.have.lengthOf(0)
      expect(aclState.TotalDocuments).to.equal(0)
    })
  })

  describe('Document Updates', () => {
    it('handles document updates by url')
    it('handles updating total document count, total term count & average document length')
  })
})
