import { expect } from 'chai'

import {
  AOTestHandle,
  createLoader,
  OWNER_ADDRESS
} from '~/test/util/setup'

describe('Wuzzy-Crawler Crawling', () => {
  let handle: AOTestHandle
  const NEST_ID = 'nestid_'.padEnd(43, '0')
  const ARIO_NETWORK_PROCESS_ID = 'ario_network_process_id_'.padEnd(43, '0')

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

  // it('should accept crawl requests', async () => {
  //   const url = 'https://memeticblock.com'
  //   const result = await handle({
  //     From: OWNER_ADDRESS,
  //     Tags: [
  //       { name: 'Action', value: 'Request-Crawl' },
  //       { name: 'URL', value: url }
  //     ]
  //   })

  //   expect(result.Messages).to.have.lengthOf(2)
  //   const [ relayRequest, requestCrawlResponse ] = result.Messages
  //   expect(relayRequest.Target).to.equal(NEST_ID)
  //   expect(relayRequest.Tags).to.deep.include({
  //     name: 'device',
  //     value: 'relay@1.0'
  //   })
  //   expect(JSON.parse(relayRequest.Data)).to.deep.equal({
  //     mode: 'call',
  //     method: 'GET',
  //     ['0']: { path: url }
  //   })
  //   expect(requestCrawlResponse.Target).to.equal(OWNER_ADDRESS)
  //   expect(requestCrawlResponse.Tags).to.deep.include({
  //     name: 'Action',
  //     value: 'Request-Crawl-Response'
  //   })
  //   expect(requestCrawlResponse.Data).to.equal('OK')
  // })
  it('should reply that http protocol is not implemented yet', async () => {
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

  it('should reply that https protocol is not implemented yet', async () => {
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

  it('should reply that arns record request was sent', async () => {
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

  it('should reply that ar protocol is not implemented yet', async () => {
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