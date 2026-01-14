import { expect } from 'chai'

import {
  AOTestHandle,
  createLoader,
  OWNER_ADDRESS
} from '../../util/setup'

describe('Search - wuzzy-nest (legacynet)', () => {
  let handle: AOTestHandle

  beforeEach(async () => {
    handle = (await createLoader('wuzzy-nest')).handle

    // Index some test documents
    await handle({
      From: OWNER_ADDRESS,
      Tags: [
        { name: 'Action', value: 'Index-Document' },
        { name: 'Document-URL', value: 'https://example.com/page1' },
        { name: 'Document-Last-Crawled-At', value: '2024-01-01T00:00:00Z' },
        { name: 'Document-Content-Type', value: 'text/html' },
        { name: 'Document-Title', value: 'First Page' },
        { name: 'Document-Description', value: 'Description of first page' }
      ],
      Data: 'This is the first page content about cats and dogs.'
    })

    await handle({
      From: OWNER_ADDRESS,
      Tags: [
        { name: 'Action', value: 'Index-Document' },
        { name: 'Document-URL', value: 'https://example.com/page2' },
        { name: 'Document-Last-Crawled-At', value: '2024-01-02T00:00:00Z' },
        { name: 'Document-Content-Type', value: 'text/html' },
        { name: 'Document-Title', value: 'Second Page' },
        { name: 'Document-Description', value: 'Description of second page' }
      ],
      Data: 'This is the second page content about birds and fish.'
    })
  })

  describe('Search (stub)', () => {
    it('Returns all documents for any query', async () => {
      const result = await handle({
        From: OWNER_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Search' },
          { name: 'Query', value: 'cats' }
        ]
      })

      expect(result.Messages).to.have.lengthOf(1)
      const searchResult = JSON.parse(result.Messages[0].Data)
      expect(searchResult.SearchType).to.equal('simple')
      expect(searchResult.Hits).to.have.lengthOf(2)
      expect(searchResult.TotalCount).to.equal(2)
    })

    it('Supports simple search type', async () => {
      const result = await handle({
        From: OWNER_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Search' },
          { name: 'Query', value: 'birds' },
          { name: 'Search-Type', value: 'simple' }
        ]
      })

      expect(result.Messages).to.have.lengthOf(1)
      const searchResult = JSON.parse(result.Messages[0].Data)
      expect(searchResult.SearchType).to.equal('simple')
    })

    it('Supports bm25 search type (stub returns all docs)', async () => {
      const result = await handle({
        From: OWNER_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Search' },
          { name: 'Query', value: 'fish' },
          { name: 'Search-Type', value: 'bm25' }
        ]
      })

      expect(result.Messages).to.have.lengthOf(1)
      const searchResult = JSON.parse(result.Messages[0].Data)
      expect(searchResult.SearchType).to.equal('bm25')
      expect(searchResult.Hits).to.have.lengthOf(2)
    })

    it('Rejects empty query', async () => {
      const result = await handle({
        From: OWNER_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Search' },
          { name: 'Query', value: '' }
        ]
      })

      expect(result.Error).to.be.a('string').that.includes('Missing Search Query')
    })

    it('Returns document metadata in hits', async () => {
      const result = await handle({
        From: OWNER_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Search' },
          { name: 'Query', value: 'test' }
        ]
      })

      expect(result.Messages).to.have.lengthOf(1)
      const searchResult = JSON.parse(result.Messages[0].Data)
      const hit = searchResult.Hits[0]
      
      expect(hit).to.have.property('DocumentId')
      expect(hit).to.have.property('URL')
      expect(hit).to.have.property('Title')
      expect(hit).to.have.property('Description')
      expect(hit).to.have.property('Score')
    })
  })
})
