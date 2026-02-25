import 'dotenv/config'
// @ts-ignore
import { connect, createSigner } from '@permaweb/aoconnect/node'
import Arweave from 'arweave'
import { loadWallet, resolveAuthority } from './util/helpers'

const WALLET_PATH = process.env.WALLET_PATH || 'wallet.json'
const HB_URL = process.env.HB_URL || 'https://push.forward.computer'
const GATEWAY_URL = process.env.GATEWAY_URL || 'https://arweave.net'
const SCHEDULER = process.env.SCHEDULER || 'n_XZJhUnmldNFo4dhajoPZWhBXuJk-OcQr5JQ49c4Zo'
const module = process.env.MODULE || 'ISShJH1ij-hPPt9St5UFFr_8Ys3Kj5cyg7zrMGt7H9s'//'wal-fUK-YnB9Kp5mN8dgMsSqPSqiGx-0SvwFUSwpDBI'
const PROCESS_NAME = process.env.PROCESS_NAME || 'default'

if (!WALLET_PATH) {
  throw new Error('Error: WALLET_PATH env var is required (path to Arweave JWK file)')
}
const wallet = loadWallet(WALLET_PATH)
const signer = createSigner(wallet)
const ao = connect({
  MODE: 'mainnet',
  signer,
  GATEWAY_URL,
  URL: HB_URL,
  SCHEDULER
})
const arweave = Arweave.init({})

async function spawn() {
  const address = await arweave.wallets.getAddress(wallet)
  console.log(`Resolving authority for [${HB_URL}]...`)
  const authority = await resolveAuthority(HB_URL)
  const scheduler = SCHEDULER || authority
  console.log(`Wallet:       ${address}`)
  console.log(`HB Node:      ${HB_URL}`)
  console.log(`Module:       ${module}`)
  console.log(`Scheduler:    ${scheduler}`)
  console.log(`Authority:    ${authority}`)
  console.log(`Process Name: ${PROCESS_NAME}`)

  console.log('Spawning process...')
  const processId = await ao.spawn({
    tags: [
      { name: 'App-Name', value: 'Wuzzy' },
      { name: 'Name', value: PROCESS_NAME },
      { name: 'Authority', value: authority }
    ],
    authority,
    module,
    signer,
    data: ''
  })
  console.log(`Process spawned: [${HB_URL}/${processId}/now/serialize~json@1.0]`)
}

spawn()
  .then(() => process.exit(0))
  .catch(e => {
    console.error(e)
    process.exit(1)
  })
