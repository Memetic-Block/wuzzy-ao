import 'dotenv/config'
import { readFileSync } from 'fs'
import { JWKInterface } from '@ardrive/turbo-sdk/lib/types/common/jwk'
import { createDataItemSigner, monitor as AoMonitor } from '@permaweb/aoconnect'
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

export async function monitor(
  processId: string,
  arweaveWalletJwk: JWKInterface
) {
  logger.info(`Monitoring AO process [${processId}]`)
  logger.info(`Using Signer Public Key [${arweaveWalletJwk.n}]`)
  const signer = createDataItemSigner(arweaveWalletJwk)

  const result = await AoMonitor({
    process: processId,
    signer
  })

  logger.info(`AO Process Monitor Result: [${result}]`)
}

monitor(PROCESS_ID, JWK).then(() => {
  logger.info('Monitor AO Process executed successfully!')
}).catch(error => {
  logger.error(`Error executing monitor AO Process:`, error)
  process.exit(1)
})
