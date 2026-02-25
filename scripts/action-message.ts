import 'dotenv/config'
// @ts-ignore
import { connect, createSigner } from '@permaweb/aoconnect/node'
// import { connect, createSigner, message } from '@permaweb/aoconnect'
import Arweave from 'arweave'
import { loadWallet, resolveAuthority } from './util/helpers'

const WALLET_PATH = process.env.WALLET_PATH || 'wallet.json'
const HB_URL = process.env.HB_URL || 'https://push.forward.computer'
const SCHEDULER = process.env.SCHEDULER || 'n_XZJhUnmldNFo4dhajoPZWhBXuJk-OcQr5JQ49c4Zo'
if (!WALLET_PATH) {
  throw new Error('Error: WALLET_PATH env var is required (path to Arweave JWK file)')
}
const processId = process.env.PROCESS_ID || ''
if (!processId) {
  throw new Error('PROCESS_ID is not set!')
}
const PROCESS_NAME = process.env.PROCESS_NAME || 'default'
const action = process.env.ACTION || ''
if (!action) {
  throw new Error('ACTION is not set!')
}
const data = process.env.DATA
const tagsInput = process.env.TAGS
const wallet = loadWallet(WALLET_PATH)
const signer = createSigner(wallet)
const ao = connect({
  MODE: 'mainnet',
  signer,
  URL: HB_URL,
  SCHEDULER
})
const arweave = Arweave.init({})
let additionalTags: { name: string; value: string }[] = []
if (tagsInput) {
  try {
    additionalTags = JSON.parse(tagsInput)
    if (!Array.isArray(additionalTags)) {
      throw new Error('TAGS must be a JSON array')
    }
  } catch (e) {
    throw new Error(`Failed to parse TAGS as JSON: ${e.message}`)
  }
}

async function sendActionMessage() {
  const address = await arweave.wallets.getAddress(wallet)
  console.log(`Resolving authority for [${HB_URL}]...`)
  const authority = await resolveAuthority(HB_URL)
  const scheduler = SCHEDULER || authority
  console.log(`Wallet:       ${address}`)
  console.log(`HB Node:      ${HB_URL}`)
  console.log(`Scheduler:    ${scheduler}`)
  console.log(`Authority:    ${authority}`)
  console.log(`Process ID:   ${processId}`)
  console.log(`Process Name: ${PROCESS_NAME}`)
  console.log(`Action:       ${action}`)
  console.log(`Additional Tags: ${JSON.stringify(additionalTags)}`)
  const tags = [
    { name: 'Action', value: action },
    ...additionalTags
  ]

  console.info(`Sending Action [${action}] to Process [${processId}] with Node [${process.env.HB_URL}]`)

  if (additionalTags.length > 0) {
    console.info(`Tags: ${JSON.stringify(additionalTags)}`)
  }

  if (data) {
    console.info(`Data: ${data}`)
  }

  const messageId = await ao.message({
    process: processId,
    tags,
    data,
    signer
  })

  console.log(`Action [${action}] sent to process [${processId}] with messageId [${messageId}], checking result...`)
  const result = await ao.result({
    process: processId,
    message: messageId
  })
  
  if (result.Error) {
    throw new Error(`Eval Action failed with error: ${result.Error}`)
  }
  console.log('Eval Action Output.prompt:', result.Output?.prompt)
  console.log(`Check state: [${HB_URL}/${processId}/now/serialize~json@1.0]`)
}

sendActionMessage()
  .then(() => process.exit(0))
  .catch(e => {
    console.error(e)
    process.exit(1)
  })
