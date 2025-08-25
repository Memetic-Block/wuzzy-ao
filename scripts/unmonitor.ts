import 'dotenv/config'
import { readFileSync } from 'fs'
import { JWKInterface } from '@ardrive/turbo-sdk/lib/types/common/jwk'
import {
  createDataItemSigner,
  unmonitor as AoUnmonitor
} from '@permaweb/aoconnect'
import { logger } from './util/logger'

const PROCESS_ID = process.env.PROCESS_ID || ''
if (!PROCESS_ID) {
  throw new Error('PROCESS_ID is not set!')
}
const PRIVATE_KEY = process.env.PRIVATE_KEY || ''
if (!PRIVATE_KEY) {
  throw new Error('PRIVATE_KEY is not set!')
}
const JWK = JSON.parse(readFileSync(PRIVATE_KEY, 'utf-8'))

export async function unmonitor(
  processId: string,
  arweaveWalletJwk: JWKInterface
) {
  logger.info(`Unmonitoring AO process [${processId}]`)
  logger.info(`Using Signer Public Key [${arweaveWalletJwk.n}]`)
  const signer = createDataItemSigner(arweaveWalletJwk)

  const result = await AoUnmonitor({
    process: processId,
    signer
  })

  logger.info(`AO Process Unmonitor Result: [${result}]`)
}

unmonitor(PROCESS_ID, JWK).then(() => {
  logger.info('Unmonitor AO Process executed successfully!')
}).catch(error => {
  logger.error(`Error executing unmonitor AO Process:`, error)
  process.exit(1)
})
