import { expect } from 'chai'

import {
  ALICE_ADDRESS,
  AOTestHandle,
  CRAWLER_A,
  CRAWLER_B,
  createLoader,
  OWNER_ADDRESS
} from '../../util/setup'

describe('Crawlers - wuzzy-nest (legacynet)', () => {
  let handle: AOTestHandle

  beforeEach(async () => {
    handle = (await createLoader('wuzzy-nest')).handle
  })

  describe('Add-Crawler', () => {
    it('Allows owner to add a crawler', async () => {
      const result = await handle({
        From: OWNER_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Add-Crawler' },
          { name: 'Crawler-Id', value: CRAWLER_A },
          { name: 'Crawler-Name', value: 'Test Crawler' }
        ]
      })

      expect(result.Messages).to.have.lengthOf(1)
      expect(result.Messages[0].Data).to.equal('OK')
      expect(result.Messages[0].Tags).to.deep.include({
        name: 'Action',
        value: 'Crawler-Added'
      })
    })

    it('Grants Index-Document role to crawler', async () => {
      // Add crawler
      await handle({
        From: OWNER_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Add-Crawler' },
          { name: 'Crawler-Id', value: CRAWLER_A },
          { name: 'Crawler-Name', value: 'Test Crawler' }
        ]
      })

      // Crawler should now be able to index documents
      const indexResult = await handle({
        From: CRAWLER_A,
        Tags: [
          { name: 'Action', value: 'Index-Document' },
          { name: 'Document-URL', value: 'https://example.com/crawled' },
          { name: 'Document-Last-Crawled-At', value: '2024-01-01T00:00:00Z' },
          { name: 'Document-Content-Type', value: 'text/html' }
        ],
        Data: 'Crawled content'
      })

      expect(indexResult.Messages).to.have.lengthOf(1)
      expect(indexResult.Messages[0].Data).to.equal('OK')
    })

    it('Rejects duplicate crawler ID', async () => {
      // Add crawler first time
      await handle({
        From: OWNER_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Add-Crawler' },
          { name: 'Crawler-Id', value: CRAWLER_A }
        ]
      })

      // Try to add same crawler ID again
      const result = await handle({
        From: OWNER_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Add-Crawler' },
          { name: 'Crawler-Id', value: CRAWLER_A }
        ]
      })

      expect(result.Error).to.be.a('string').that.includes('Crawler-Id already exists')
    })

    it('Rejects missing Crawler-Id', async () => {
      const result = await handle({
        From: OWNER_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Add-Crawler' },
          { name: 'Crawler-Name', value: 'Test Crawler' }
        ]
      })

      expect(result.Error).to.be.a('string').that.includes('Crawler-Id is required')
    })

    it('Denies unauthorized users from adding crawlers', async () => {
      const result = await handle({
        From: ALICE_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Add-Crawler' },
          { name: 'Crawler-Id', value: CRAWLER_A }
        ]
      })

      expect(result.Error).to.be.a('string').that.includes('Permission Denied')
    })
  })

  describe('Remove-Crawler', () => {
    beforeEach(async () => {
      // Add a crawler to remove
      await handle({
        From: OWNER_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Add-Crawler' },
          { name: 'Crawler-Id', value: CRAWLER_A },
          { name: 'Crawler-Name', value: 'Test Crawler' }
        ]
      })
    })

    it('Allows owner to remove a crawler', async () => {
      const result = await handle({
        From: OWNER_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Remove-Crawler' },
          { name: 'Crawler-Id', value: CRAWLER_A }
        ]
      })

      expect(result.Messages).to.have.lengthOf(1)
      expect(result.Messages[0].Data).to.equal('OK')
      expect(result.Messages[0].Tags).to.deep.include({
        name: 'Action',
        value: 'Crawler-Removed'
      })
    })

    it('Revokes Index-Document role from removed crawler', async () => {
      // Remove crawler
      await handle({
        From: OWNER_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Remove-Crawler' },
          { name: 'Crawler-Id', value: CRAWLER_A }
        ]
      })

      // Crawler should no longer be able to index documents
      const indexResult = await handle({
        From: CRAWLER_A,
        Tags: [
          { name: 'Action', value: 'Index-Document' },
          { name: 'Document-URL', value: 'https://example.com/crawled' },
          { name: 'Document-Last-Crawled-At', value: '2024-01-01T00:00:00Z' },
          { name: 'Document-Content-Type', value: 'text/html' }
        ],
        Data: 'Crawled content'
      })

      expect(indexResult.Error).to.be.a('string').that.includes('Permission Denied')
    })

    it('Rejects removing non-existent crawler', async () => {
      const result = await handle({
        From: OWNER_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Remove-Crawler' },
          { name: 'Crawler-Id', value: CRAWLER_B }
        ]
      })

      expect(result.Error).to.be.a('string').that.includes('Crawler-Id does not exist')
    })

    it('Denies unauthorized users from removing crawlers', async () => {
      const result = await handle({
        From: ALICE_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Remove-Crawler' },
          { name: 'Crawler-Id', value: CRAWLER_A }
        ]
      })

      expect(result.Error).to.be.a('string').that.includes('Permission Denied')
    })
  })
})
