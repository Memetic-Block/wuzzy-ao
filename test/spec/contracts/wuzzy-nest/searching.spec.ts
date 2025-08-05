import { expect } from 'chai'

import {
  AOTestHandle,
  createLoader,
  OWNER_ADDRESS
} from '~/test/util/setup'

describe('Wuzzy-Nest Searching', () => {
  let handle: AOTestHandle

  beforeEach(async () => {
    handle = (await createLoader('wuzzy-nest')).handle
  })

  it('should validate search queries')

  it('should accept simple search queries', async () => {
    const crawlerAddress = 'CRAWLER_ADDRESS'
    const indexType = 'ARNS'
    const arnsSubdomain = '@'
    const documents = [
      {
        arnsName: 'artbycity',
        contentType: 'text/plain',
        transactionId: '67890',
        content: 'This is another test document from artbycity'
      },
      {
        arnsName: 'memeticblock',
        contentType: 'text/plain',
        transactionId: '12345',
        content: 'This is a test document from memeticblock, it says test twice'
      },
      {
        arnsName: 'wuzzy',
        contentType: 'text/plain',
        transactionId: '54321',
        content: 'This is yet another test document from wuzzy'
      }
    ]

    for (const doc of documents) {
      await handle({
        From: crawlerAddress,
        Tags: [
          { name: 'Action', value: 'Index' },
          { name: 'Index-Type', value: indexType },
          { name: 'Document-ARNS-Name', value: doc.arnsName },
          { name: 'Document-ARNS-Sub-Domain', value: arnsSubdomain },
          { name: 'Document-Content-Type', value: doc.contentType },
          { name: 'Document-Transaction-Id', value: doc.transactionId }
        ],
        Data: doc.content
      })
    }

    const searchOneResult = await handle({
      From: OWNER_ADDRESS,
      Tags: [
        { name: 'Action', value: 'Search' },
        { name: 'Query', value: 'memeticblock' }
      ]
    })
    if (searchOneResult.Error) {
      console.log(`DEBUG - AO Message Error: ${searchOneResult.Error}`)
    }
    expect(searchOneResult.Error).to.not.exist
    expect(searchOneResult.Messages).to.have.lengthOf(1)
    expect(searchOneResult.Messages[0].Data).to.exist
    const searchResults = JSON.parse(searchOneResult.Messages[0].Data)
    expect(searchResults.TotalCount).to.equal(1)
    expect(searchResults.Hits).to.have.lengthOf(1)
    expect(searchResults.Hits[0].doc.TransactionId).to.equal('12345')

    const searchTwoResult = await handle({
      From: OWNER_ADDRESS,
      Tags: [
        { name: 'Action', value: 'Search' },
        { name: 'Query', value: 'another' }
      ]
    })
    if (searchTwoResult.Error) {
      console.log(`DEBUG - AO Message Error: ${searchTwoResult.Error}`)
    }
    expect(searchTwoResult.Error).to.not.exist
    expect(searchTwoResult.Messages).to.have.lengthOf(1)
    expect(searchTwoResult.Messages[0].Data).to.exist
    const searchTwoResults = JSON.parse(searchTwoResult.Messages[0].Data)
    expect(searchTwoResults.TotalCount).to.equal(2)
    expect(searchTwoResults.Hits).to.have.lengthOf(2)
    expect(searchTwoResults.Hits[0].doc.TransactionId).to.equal('67890')
    expect(searchTwoResults.Hits[1].doc.TransactionId).to.equal('54321')

    const searchThreeResult = await handle({
      From: OWNER_ADDRESS,
      Tags: [
        { name: 'Action', value: 'Search' },
        { name: 'Query', value: 'nonexistent' }
      ]
    })
    if (searchThreeResult.Error) {
      console.log(`DEBUG - AO Message Error: ${searchThreeResult.Error}`)
    }
    expect(searchThreeResult.Error).to.not.exist
    expect(searchThreeResult.Messages).to.have.lengthOf(1)
    expect(searchThreeResult.Messages[0].Data).to.exist
    const searchThreeResults = JSON.parse(searchThreeResult.Messages[0].Data)
    expect(searchThreeResults.TotalCount).to.equal(0)
    expect(searchThreeResults.Hits).to.have.lengthOf(0)

    const searchFourResult = await handle({
      From: OWNER_ADDRESS,
      Tags: [
        { name: 'Action', value: 'Search' },
        { name: 'Query', value: 'test' }
      ]
    })
    if (searchFourResult.Error) {
      console.log(`DEBUG - AO Message Error: ${searchFourResult.Error}`)
    }
    expect(searchFourResult.Error).to.not.exist
    expect(searchFourResult.Messages).to.have.lengthOf(1)
    expect(searchFourResult.Messages[0].Data).to.exist
    const searchFourResults = JSON.parse(searchFourResult.Messages[0].Data)
    expect(searchFourResults.TotalCount).to.equal(3)
    expect(searchFourResults.Hits).to.have.lengthOf(3)
    // NB: memeticblock content says query twice, so should be ranked first
    expect(searchFourResults.Hits[0].doc.TransactionId).to.equal('12345')
    expect(searchFourResults.Hits[1].doc.TransactionId).to.equal('67890')
    expect(searchFourResults.Hits[2].doc.TransactionId).to.equal('54321')
  })

  it('should accept bm25 search queries', async () => {
    const crawlerAddress = 'CRAWLER_ADDRESS'
    const indexType = 'ARNS'
    const arnsSubdomain = '@'
    const documents = [
      {
        arnsName: 'wuzzy1',
        contentType: 'text/plain',
        transactionId: '11111',
        content: 'Wuzzy'
      },
      {
        arnsName: 'wuzzy2',
        contentType: 'text/plain',
        transactionId: '22222',
        content: 'Wuzzy S'
      },
      {
        arnsName: 'wuzzy3',
        contentType: 'text/plain',
        transactionId: '33333',
        content: 'Wuzzy AO Search'
      },
      {
        arnsName: 'wuzzy4',
        contentType: 'text/plain',
        transactionId: '44444',
        content: 'Wuzzy Search'
      },
      {
        arnsName: 'wuzzy5',
        contentType: 'text/plain',
        transactionId: '55555',
        content: 'Wuzzy Wuzzy Search Search'
      },
      {
        arnsName: 'wuzzy6',
        contentType: 'text/plain',
        transactionId: '66666',
        content: 'Wuzzy Wuzzy Wuzzy Search Search Search'
      }
    ]

    for (const doc of documents) {
      await handle({
        From: crawlerAddress,
        Tags: [
          { name: 'Action', value: 'Index' },
          { name: 'Index-Type', value: indexType },
          { name: 'Document-ARNS-Name', value: doc.arnsName },
          { name: 'Document-ARNS-Sub-Domain', value: arnsSubdomain },
          { name: 'Document-Content-Type', value: doc.contentType },
          { name: 'Document-Transaction-Id', value: doc.transactionId }
        ],
        Data: doc.content
      })
    }

    const searchOneResult = await handle({
      From: OWNER_ADDRESS,
      Tags: [
        { name: 'Action', value: 'Search' },
        { name: 'Query', value: 'Wuzzy' },
        { name: 'Search-Type', value: 'bm25' }
      ]
    })
    if (searchOneResult.Error) {
      console.log(`DEBUG - AO Message Error: ${searchOneResult.Error}`)
    }
    expect(searchOneResult.Error).to.not.exist
    expect(searchOneResult.Messages).to.have.lengthOf(1)
    expect(searchOneResult.Messages[0].Data).to.exist
    const searchResults = JSON.parse(searchOneResult.Messages[0].Data)
    expect(searchResults.SearchType).to.equal('bm25')
    expect(searchResults.TotalCount).to.equal(6)
    expect(searchResults.Hits).to.have.lengthOf(6)
    expect(searchResults.Hits[0].doc.TransactionId).to.equal('11111')
  })
})
