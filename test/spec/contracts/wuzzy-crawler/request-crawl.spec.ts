import { expect } from 'chai'

import {
  AOTestHandle,
  ARIO_NETWORK_PROCESS_ID,
  createLoader,
  NEST_ID,
  OWNER_ADDRESS
} from '~/test/util/setup'

describe('Wuzzy-Crawler Request-Crawl', () => {
  let handle: AOTestHandle

  beforeEach(async () => {
    handle = (await createLoader(
      'wuzzy-crawler', {
        processTags: [
          { name: 'Nest-Id', value: NEST_ID },
          { name: 'Ario-Network-Process-Id', value: ARIO_NETWORK_PROCESS_ID }
        ]
      }
    )).handle
  })

  it('replies that http protocol is not implemented yet', async () => {
    const url = 'http://memeticblock.com'
    const result = await handle({
      From: OWNER_ADDRESS,
      Tags: [
        { name: 'Action', value: 'Request-Crawl' },
        { name: 'URL', value: url }
      ]
    })
    expect(result.Messages).to.have.lengthOf(1)
    const response = result.Messages[0]
    expect(response.Target).to.equal(OWNER_ADDRESS)
    expect(response.Tags).to.deep.include({
      name: 'Action',
      value: 'Request-Crawl-Response'
    })
    expect(response.Data)
      .to.equal('http://|https:// protocol is not implemented yet')
  })

  it('replies that https protocol is not implemented yet', async () => {
    const url = 'https://memeticblock.com'
    const result = await handle({
      From: OWNER_ADDRESS,
      Tags: [
        { name: 'Action', value: 'Request-Crawl' },
        { name: 'URL', value: url }
      ]
    })
    expect(result.Messages).to.have.lengthOf(1)
    const response = result.Messages[0]
    expect(response.Target).to.equal(OWNER_ADDRESS)
    expect(response.Tags).to.deep.include({
      name: 'Action',
      value: 'Request-Crawl-Response'
    })
    expect(response.Data)
      .to.equal('http://|https:// protocol is not implemented yet')
  })

  it('replies that arns record request was sent', async () => {
    const name = 'memeticblock'
    const url = `arns://${name}`

    const result = await handle({
      From: OWNER_ADDRESS,
      Tags: [
        { name: 'Action', value: 'Request-Crawl' },
        { name: 'URL', value: url }
      ]
    })

    expect(result.Messages).to.have.lengthOf(2)
    const [ arnsRequest, response ] = result.Messages
    expect(arnsRequest.Target).to.equal(ARIO_NETWORK_PROCESS_ID)
    expect(arnsRequest.Tags).to.deep.include({
      name: 'Action',
      value: 'Record'
    })
    expect(arnsRequest.Tags).to.deep.include({
      name: 'Name',
      value: name
    })
    expect(response.Target).to.equal(OWNER_ADDRESS)
    expect(response.Tags).to.deep.include({
      name: 'Action',
      value: 'Request-Crawl-Response'
    })
    expect(response.Data)
      .to.equal(`Record request sent to ARNS registry: ${name}`)
  })

  it('replies that ar protocol is not implemented yet', async () => {
    const txId = 'txid_'.padEnd(43, 'q')
    const url = `ar://${txId}`
    const result = await handle({
      From: OWNER_ADDRESS,
      Tags: [
        { name: 'Action', value: 'Request-Crawl' },
        { name: 'URL', value: url }
      ]
    })

    expect(result.Messages).to.have.lengthOf(1)
    const response = result.Messages[0]
    expect(response.Target).to.equal(OWNER_ADDRESS)
    expect(response.Tags).to.deep.include({
      name: 'Action',
      value: 'Request-Crawl-Response'
    })
    expect(response.Data).to.equal('ar:// protocol is not implemented yet')
  })
})
