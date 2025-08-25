import { expect } from 'chai'

import {
  AOTestHandle,
  ARIO_NETWORK_PROCESS_ID,
  createLoader,
  NEST_ID,
  OWNER_ADDRESS
} from '~/test/util/setup'

describe('Wuzzy-Crawler Crawling', () => {
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

  it('todo')
})
