import { expect } from 'chai'

import {
  ANT_PROCESS_ID,
  AOTestHandle,
  ARIO_NETWORK_PROCESS_ID,
  createLoader,
  NEST_ID,
  ORACLE_ADDRESS,
  OWNER_ADDRESS
} from '~/test/util/setup'
import MockTransactions from '~/test/util/mock-transactions.json'

describe('Wuzzy-Crawler Get-Data', () => {
  let handle: AOTestHandle

  beforeEach(async () => {
    handle = (await createLoader(
      'wuzzy-crawler', {
        processTags: [
          { name: 'Nest-Id', value: NEST_ID },
          { name: 'Ario-Network-Process-Id', value: ARIO_NETWORK_PROCESS_ID },
          { name: 'Data-Oracle-Address', value: ORACLE_ADDRESS }
        ]
      }
    )).handle
  })

  it('validates Get-Data-Result messages')
  it('ignores unexpected Get-Data-Result messages')
  it('ignores unknown Get-Data-Result messages')
  it('handles error results from Get-Data-Result messages')
  it('results in error when data is empty')
  it('sends success result to requestor')
  it('sends error result to requestor')
})