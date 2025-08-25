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

describe('Wuzzy-Crawler Get-Transaction', () => {
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

  it('validates Get-Transaction-Result messages')
  it('ignores unexpected Get-Transaction-Result messages')
  it('ignores unknown Get-Transaction-Result messages')
  it('handles error results from Get-Transaction-Result messages')
  it('does not request Get-Data for transactions that are too large')
  it('does not request Get-Data for transactions that have invalid Content-Type')
  it('requests Get-Data for valid transactions')
})
