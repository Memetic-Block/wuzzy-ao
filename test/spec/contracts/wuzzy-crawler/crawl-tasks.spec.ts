import { expect } from 'chai'

import {
  ALICE_ADDRESS,
  AOTestHandle,
  BOB_ADDRESS,
  createLoader,
  OWNER_ADDRESS
} from '~/test/util/setup'

describe('Wuzzy-Crawler Crawl-Tasks', () => {
  let handle: AOTestHandle

  beforeEach(async () => {
    handle = (await createLoader('wuzzy-crawler')).handle
  })

  describe('Add-Crawl-Tasks', () => {
    it('rejects Add-Crawl-Tasks messages from unknown callers', async () => {
      const result = await handle({
        From: ALICE_ADDRESS,
        Tags: [ { name: 'Action', value: 'Add-Crawl-Tasks' } ],
        Data: 'fake crawl task'
      })

      expect(result.Error).to.exist
      expect(result.Error).to.include('Permission Denied')
    })

    it('validates Add-Crawl-Tasks messages', async () => {
      const noDataResult = await handle({
        From: OWNER_ADDRESS,
        Tags: [ { name: 'Action', value: 'Add-Crawl-Tasks' } ]
      })
      expect(noDataResult.Error).to.exist
      expect(noDataResult.Error).to.include('Missing Crawl Task Data')

      const invalidUrl = '1234'
      const invalidUrlResult = await handle({
        From: OWNER_ADDRESS,
        Tags: [ { name: 'Action', value: 'Add-Crawl-Tasks' } ],
        Data: invalidUrl
      })
      expect(invalidUrlResult.Error).to.exist
      expect(invalidUrlResult.Error).to.include(
        `Invalid Crawl Task Data: ${invalidUrl}`
      )
    })

    it('temporarily rejects Add-Crawl-Tasks for http/https urls', async () => {
      const httpUrl = 'http://example.com'
      const httpsUrl = 'https://example.com'

      const httpResult = await handle({
        From: OWNER_ADDRESS,
        Tags: [ { name: 'Action', value: 'Add-Crawl-Tasks' } ],
        Data: httpUrl
      })
      expect(httpResult.Error).to.exist
      expect(httpResult.Error).to.include(
        `The http protocol is not yet supported: ${httpUrl}`
      )

      const httpsResult = await handle({
        From: OWNER_ADDRESS,
        Tags: [ { name: 'Action', value: 'Add-Crawl-Tasks' } ],
        Data: httpsUrl
      })
      expect(httpsResult.Error).to.exist
      expect(httpsResult.Error).to.include(
        `The https protocol is not yet supported: ${httpsUrl}`
      )
    })

    it('rejects duplicate crawl tasks', async () => {
      const url = 'arns://memeticblock'
      await handle({
        From: OWNER_ADDRESS,
        Tags: [ { name: 'Action', value: 'Add-Crawl-Tasks' } ],
        Data: url
      })
      const duplicateResult = await handle({
        From: OWNER_ADDRESS,
        Tags: [ { name: 'Action', value: 'Add-Crawl-Tasks' } ],
        Data: url
      })
      expect(duplicateResult.Error).to.exist
      expect(duplicateResult.Error).to.include(`Duplicate Crawl Task: ${url}`)
    })

    it('accepts Add-Crawl-Tasks messages from Owner, admin, ACL', async () => {
      await handle({
        From: OWNER_ADDRESS,
        Tags: [ { name: 'Action', value: 'Update-Roles' } ],
        Data: JSON.stringify({
          Grant: {
            [ALICE_ADDRESS]: [ 'admin' ],
            [BOB_ADDRESS]: [ 'Add-Crawl-Tasks' ]
          }
        })
      })

      const ownerResult = await handle({
        From: OWNER_ADDRESS,
        Tags: [ { name: 'Action', value: 'Add-Crawl-Tasks' } ],
        Data: 'arns://memeticblock'
      })
      expect(ownerResult.Error).to.not.exist
      expect(ownerResult.Messages).to.have.lengthOf(1)
      expect(ownerResult.Messages[0].Target).to.equal(OWNER_ADDRESS)
      expect(ownerResult.Messages[0].Data).to.equal('OK')
      expect(ownerResult.Messages[0].Tags).to.deep.include({
        name: 'Action',
        value: 'Add-Crawl-Tasks-Result'
      })

      const adminResult = await handle({
        From: ALICE_ADDRESS,
        Tags: [ { name: 'Action', value: 'Add-Crawl-Tasks' } ],
        Data: 'arns://wuzzy'
      })
      expect(adminResult.Error).to.not.exist
      expect(adminResult.Messages).to.have.lengthOf(1)
      expect(adminResult.Messages[0].Target).to.equal(ALICE_ADDRESS)
      expect(adminResult.Messages[0].Data).to.equal('OK')
      expect(adminResult.Messages[0].Tags).to.deep.include({
        name: 'Action',
        value: 'Add-Crawl-Tasks-Result'
      })

      const aclResult = await handle({
        From: BOB_ADDRESS,
        Tags: [ { name: 'Action', value: 'Add-Crawl-Tasks' } ],
        Data: 'arns://cookbook'
      })
      expect(aclResult.Error).to.not.exist
      expect(aclResult.Messages).to.have.lengthOf(1)
      expect(aclResult.Messages[0].Target).to.equal(BOB_ADDRESS)
      expect(aclResult.Messages[0].Data).to.equal('OK')
      expect(aclResult.Messages[0].Tags).to.deep.include({
        name: 'Action',
        value: 'Add-Crawl-Tasks-Result'
      })

      const viewStateResult = await handle({
        From: OWNER_ADDRESS,
        Tags: [ { name: 'Action', value: 'View-State' } ]
      })
      expect(viewStateResult.Error).to.not.exist
      expect(viewStateResult.Messages).to.have.lengthOf(1)
      expect(viewStateResult.Messages[0].Data).to.exist
      const state = JSON.parse(viewStateResult.Messages[0].Data)
      expect(state.CrawlTasks).to.be.an('object')
      expect(Object.keys(state.CrawlTasks)).to.have.lengthOf(3)
      expect(state.CrawlTasks['arns://memeticblock']).to.exist
      expect(state.CrawlTasks['arns://wuzzy']).to.exist
      expect(state.CrawlTasks['arns://cookbook']).to.exist
    })
  })

  describe('Remove-Crawl-Tasks', () => {
    it('rejects Remove-Crawl-Tasks messages from unknown callers', async () => {
      const result = await handle({
        From: ALICE_ADDRESS,
        Tags: [ { name: 'Action', value: 'Remove-Crawl-Tasks' } ],
        Data: 'fake crawl task'
      })

      expect(result.Error).to.exist
      expect(result.Error).to.include('Permission Denied')
    })

    it('validates Remove-Crawl-Tasks messages', async () => {
      const noDataResult = await handle({
        From: OWNER_ADDRESS,
        Tags: [ { name: 'Action', value: 'Remove-Crawl-Tasks' } ]
      })
      expect(noDataResult.Error).to.exist
      expect(noDataResult.Error).to.include('Missing Crawl Task Data to remove')

      const url = 'arns://memeticblock'
      const nothingToRemoveResult = await handle({
        From: OWNER_ADDRESS,
        Tags: [ { name: 'Action', value: 'Remove-Crawl-Tasks' } ],
        Data: url
      })
      expect(nothingToRemoveResult.Error).to.exist
      expect(nothingToRemoveResult.Error).to.include(
        `Crawl Task not found: ${url}`
      )
    })

    it('accepts Remove-Crawl-Tasks messages from Owner, admin, ACL', async () => {
      const urls = [ 'arns://memeticblock', 'arns://wuzzy', 'arns://cookbook' ]
      await handle({
        From: OWNER_ADDRESS,
        Tags: [ { name: 'Action', value: 'Add-Crawl-Tasks' } ],
        Data: urls.join('\n')
      })
      await handle({
        From: OWNER_ADDRESS,
        Tags: [ { name: 'Action', value: 'Update-Roles' } ],
        Data: JSON.stringify({
          Grant: {
            [ALICE_ADDRESS]: [ 'admin' ],
            [BOB_ADDRESS]: [ 'Remove-Crawl-Tasks' ]
          }
        })
      })

      const ownerResult = await handle({
        From: OWNER_ADDRESS,
        Tags: [ { name: 'Action', value: 'Remove-Crawl-Tasks' } ],
        Data: urls[0]
      })
      expect(ownerResult.Error).to.not.exist
      expect(ownerResult.Messages).to.have.lengthOf(1)
      expect(ownerResult.Messages[0].Target).to.equal(OWNER_ADDRESS)
      expect(ownerResult.Messages[0].Data).to.equal('OK')

      const adminResult = await handle({
        From: ALICE_ADDRESS,
        Tags: [ { name: 'Action', value: 'Remove-Crawl-Tasks' } ],
        Data: urls[1]
      })
      expect(adminResult.Error).to.not.exist
      expect(adminResult.Messages).to.have.lengthOf(1)
      expect(adminResult.Messages[0].Target).to.equal(ALICE_ADDRESS)
      expect(adminResult.Messages[0].Data).to.equal('OK')

      const aclResult = await handle({
        From: BOB_ADDRESS,
        Tags: [ { name: 'Action', value: 'Remove-Crawl-Tasks' } ],
        Data: urls[2]
      })
      expect(aclResult.Error).to.not.exist
      expect(aclResult.Messages).to.have.lengthOf(1)
      expect(aclResult.Messages[0].Target).to.equal(BOB_ADDRESS)
      expect(aclResult.Messages[0].Data).to.equal('OK')

      const viewStateResult = await handle({
        From: OWNER_ADDRESS,
        Tags: [ { name: 'Action', value: 'View-State' } ]
      })
      expect(viewStateResult.Error).to.not.exist
      expect(viewStateResult.Messages).to.have.lengthOf(1)
      expect(viewStateResult.Messages[0].Data).to.exist
      const state = JSON.parse(viewStateResult.Messages[0].Data)
      expect(state.CrawlTasks).to.be.an('array')
      expect(state.CrawlTasks).to.have.lengthOf(0)
      expect(state.CrawlTasks[urls[0]]).to.not.exist
      expect(state.CrawlTasks[urls[1]]).to.not.exist
      expect(state.CrawlTasks[urls[2]]).to.not.exist
    })
  })
})
