import { expect } from 'chai'

import {
  ALICE_ADDRESS,
  AOTestHandle,
  CRAWLER_A,
  createLoader,
  OWNER_ADDRESS
} from '../../util/setup'

describe('Document Indexing - wuzzy-nest (legacynet)', () => {
  let handle: AOTestHandle

  beforeEach(async () => {
    handle = (await createLoader('wuzzy-nest')).handle
  })

  describe('Index-Document', () => {
    it('Allows owner to index a document', async () => {
      const result = await handle({
        From: OWNER_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Index-Document' },
          { name: 'Document-URL', value: 'https://example.com/page1' },
          { name: 'Document-Last-Crawled-At', value: '2024-01-01T00:00:00Z' },
          { name: 'Document-Content-Type', value: 'text/html' },
          { name: 'Document-Title', value: 'Example Page' },
          { name: 'Document-Description', value: 'An example page' }
        ],
        Data: 'This is the content of the page with some words for indexing.'
      })

      expect(result.Messages).to.have.lengthOf(1)
      expect(result.Messages[0].Data).to.equal('OK')
      expect(result.Messages[0].Tags).to.deep.include({
        name: 'Action',
        value: 'Index-Document-Result'
      })
    })

    it('Rejects indexing without Document-URL', async () => {
      const result = await handle({
        From: OWNER_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Index-Document' },
          { name: 'Document-Last-Crawled-At', value: '2024-01-01T00:00:00Z' },
          { name: 'Document-Content-Type', value: 'text/html' }
        ],
        Data: 'Some content'
      })

      expect(result.Error).to.be.a('string').that.includes('Missing Document-URL')
    })

    it('Rejects indexing without content', async () => {
      const result = await handle({
        From: OWNER_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Index-Document' },
          { name: 'Document-URL', value: 'https://example.com/page1' },
          { name: 'Document-Last-Crawled-At', value: '2024-01-01T00:00:00Z' },
          { name: 'Document-Content-Type', value: 'text/html' }
        ],
        Data: ''
      })

      expect(result.Error).to.be.a('string').that.includes('Missing Document Content')
    })

    it('Denies unauthorized users from indexing', async () => {
      const result = await handle({
        From: ALICE_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Index-Document' },
          { name: 'Document-URL', value: 'https://example.com/page1' },
          { name: 'Document-Last-Crawled-At', value: '2024-01-01T00:00:00Z' },
          { name: 'Document-Content-Type', value: 'text/html' }
        ],
        Data: 'Some content'
      })

      expect(result.Error).to.be.a('string').that.includes('Permission Denied')
    })

    it('Updates existing document on re-index', async () => {
      // Index first time
      await handle({
        From: OWNER_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Index-Document' },
          { name: 'Document-URL', value: 'https://example.com/page1' },
          { name: 'Document-Last-Crawled-At', value: '2024-01-01T00:00:00Z' },
          { name: 'Document-Content-Type', value: 'text/html' },
          { name: 'Document-Title', value: 'Original Title' }
        ],
        Data: 'Original content'
      })

      // Index same URL again with updated content
      const result = await handle({
        From: OWNER_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Index-Document' },
          { name: 'Document-URL', value: 'https://example.com/page1' },
          { name: 'Document-Last-Crawled-At', value: '2024-01-02T00:00:00Z' },
          { name: 'Document-Content-Type', value: 'text/html' },
          { name: 'Document-Title', value: 'Updated Title' }
        ],
        Data: 'Updated content with more words'
      })

      expect(result.Messages).to.have.lengthOf(1)
      expect(result.Messages[0].Data).to.equal('OK')
    })
  })

  describe('Remove-Document', () => {
    it('Allows owner to remove a document', async () => {
      // First index a document
      await handle({
        From: OWNER_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Index-Document' },
          { name: 'Document-URL', value: 'https://example.com/page1' },
          { name: 'Document-Last-Crawled-At', value: '2024-01-01T00:00:00Z' },
          { name: 'Document-Content-Type', value: 'text/html' }
        ],
        Data: 'Some content'
      })

      // Then remove it
      const result = await handle({
        From: OWNER_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Remove-Document' },
          { name: 'Document-Id', value: 'https://example.com/page1' }
        ]
      })

      expect(result.Messages).to.have.lengthOf(1)
      expect(result.Messages[0].Data).to.equal('OK')
    })

    it('Rejects removing non-existent document', async () => {
      const result = await handle({
        From: OWNER_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Remove-Document' },
          { name: 'Document-Id', value: 'https://nonexistent.com/page' }
        ]
      })

      expect(result.Error).to.be.a('string').that.includes('Document not found')
    })
  })
})
