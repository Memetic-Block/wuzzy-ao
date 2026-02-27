import 'dotenv/config'
import Arweave from 'arweave'
import { loadWallet, resolveAuthority } from './util/helpers'
import { spawnProcess } from './tools/spawn'
import { doEval } from './tools/eval'
import { sendActionMessage } from './tools/action-message'

const WALLET_PATH = process.env.WALLET_PATH || 'wallet.json'
const HB_URL = process.env.HB_URL || 'https://push.forward.computer'
const GATEWAY_URL = process.env.GATEWAY_URL || 'https://arweave.net'
const SCHEDULER = process.env.SCHEDULER || 'n_XZJhUnmldNFo4dhajoPZWhBXuJk-OcQr5JQ49c4Zo'
const MODULE = process.env.MODULE || 'ISShJH1ij-hPPt9St5UFFr_8Ys3Kj5cyg7zrMGt7H9s'

async function bootstrap() {
  const wallet = loadWallet(WALLET_PATH)
  const arweave = Arweave.init({})
  const address = await arweave.wallets.getAddress(wallet)
  const authority = await resolveAuthority(HB_URL)
  const scheduler = SCHEDULER || authority

  console.log('=== Bootstrap Dev Environment ===')
  console.log(`Wallet:    ${address}`)
  console.log(`HB Node:   ${HB_URL}`)
  console.log(`Module:    ${MODULE}`)
  console.log(`Scheduler: ${scheduler}`)
  console.log(`Authority: ${authority}`)
  console.log()

  // 1. Spawn nest-registry
  console.log('--- Step 1: Spawn nest-registry ---')
  const nestRegistryId = await spawnProcess({
    wallet,
    hyperbeamUrl: HB_URL,
    gatewayUrl: GATEWAY_URL,
    scheduler,
    authority,
    module: MODULE,
    processName: 'nest-registry'
  })

  // 2. Eval nest-registry
  console.log('--- Step 2: Eval nest-registry ---')
  await doEval({
    wallet,
    hyperbeamUrl: HB_URL,
    scheduler,
    processId: nestRegistryId,
    processName: 'nest-registry'
  })

  // 3. Spawn crawl-request-queue with Nest-Registry tag
  console.log('--- Step 3: Spawn crawl-request-queue ---')
  const crawlRequestQueueId = await spawnProcess({
    wallet,
    hyperbeamUrl: HB_URL,
    gatewayUrl: GATEWAY_URL,
    scheduler,
    authority,
    module: MODULE,
    processName: 'crawl-request-queue',
    additionalTags: [
      { name: 'Nest-Registry', value: nestRegistryId }
    ]
  })

  // 4. Eval crawl-request-queue
  console.log('--- Step 4: Eval crawl-request-queue ---')
  await doEval({
    wallet,
    hyperbeamUrl: HB_URL,
    scheduler,
    processId: crawlRequestQueueId,
    processName: 'crawl-request-queue'
  })

  // 5. Link nest-registry → crawl-request-queue
  console.log('--- Step 5: Link nest-registry to crawl-request-queue ---')
  await sendActionMessage({
    wallet,
    hyperbeamUrl: HB_URL,
    authority,
    scheduler,
    processId: nestRegistryId,
    action: 'Set-Crawl-Request-Queue',
    additionalTags: [
      { name: 'Crawl-Request-Queue', value: crawlRequestQueueId }
    ]
  })

  console.log()
  console.log('=== Bootstrap Complete ===')
  console.log(`Nest Registry:       ${nestRegistryId}`)
  console.log(`Crawl Request Queue: ${crawlRequestQueueId}`)
}

bootstrap()
  .then(() => process.exit(0))
  .catch(e => {
    console.error(e)
    process.exit(1)
  })
