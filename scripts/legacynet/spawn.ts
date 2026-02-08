import 'dotenv/config'
import { readFileSync } from 'fs'
import { join, resolve } from 'path'
import { createDataItemSigner, spawn } from '@permaweb/aoconnect'
import { Arweave, ArweaveSigner } from '@dha-team/arbundles'
import { sendAosMessage } from '../util/send-aos-message'

const processName = process.env.PROCESS_NAME || ''
const appName = process.env.APP_NAME || 'Wuzzy'
const deployerPrivateKeyPath = process.env.DEPLOYER_PRIVATE_KEY_PATH || ''
const schedulerAddress = process.env.SCHEDULER
  || '_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA'
const authorityAddress = process.env.AUTHORITY
  || 'fcoN_xJeisVsPXA-trzVAuIiqO3ydLQxM-L4XbrQKzY'
const aosModuleId = process.env.AOS_MODULE_ID
  || 'ISShJH1ij-hPPt9St5UFFr_8Ys3Kj5cyg7zrMGt7H9s'
const processSourcePath = process.env.PROCESS_SOURCE_PATH || ''
const callInitHandler = process.env.CALL_INIT_HANDLER === 'true'
const initDataPath = process.env.INIT_DATA_PATH
const initDelayMs = parseInt(process.env.INIT_DELAY_MS || '30000', 10)
const tagsInput = process.env.TAGS || ''
let initData: string | undefined

if (!processName) { throw new Error('PROCESS_NAME is not set!') }
if (!processSourcePath) { throw new Error('PROCESS_SOURCE_PATH is not set!') }
if (!deployerPrivateKeyPath) {
  throw new Error('DEPLOYER_PRIVATE_KEY_PATH is not set!')
}
if (callInitHandler) {
  if (!initDataPath) {
    throw new Error('CALL_INIT_HANDLER is true but INIT_DATA_PATH is not set!')
  }
  initData = readFileSync(initDataPath, 'utf8')
  if (!initData) {
    throw new Error('INIT_DATA_PATH is set but file is empty!')
  }
}

// Parse additional tags from TAGS env var (JSON array of {name, value} objects)
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

async function deploy() {
  const source = readFileSync(join(resolve(), processSourcePath), 'utf8')
  console.info(`Read process source from [${processSourcePath}]`)
  const jwk = JSON.parse(readFileSync(deployerPrivateKeyPath, 'utf-8'))
  const address = await Arweave.init({}).wallets.jwkToAddress(jwk)
  const wallet = new ArweaveSigner(jwk)
  console.info(`Signing using wallet with address [${address}]`)
  const signer = await createDataItemSigner(jwk)
  console.info(`Spawning new AO process for [${processName}]`)
  const processId = await spawn({
    module: aosModuleId,
    scheduler: schedulerAddress,
    signer: signer as any,
    tags: [
      { name: 'App-Name', value: appName },
      { name: 'Contract-Name', value: processName },
      { name: 'Authority', value: authorityAddress },
      { name: 'Spawn-Timestamp', value: Date.now().toString() },
      ...additionalTags
    ],
    data: 'Search the Permaweb at wuzzy.arweave.net!'
  })

  console.info(
    `Sending Action: Eval of [${processName}] to AO Process [${processId}]`
  )
  await sendAosMessage({
    processId,
    data: source,
    signer: signer as any,
    tags: [
      { name: 'Action', value: 'Eval' },
      { name: 'App-Name', value: appName }
    ]
  })

  console.info(`Process Published and Evaluated at [${processId}]`)

  if (callInitHandler) {
    console.info(
      `Sleeping ${initDelayMs / 1000}s to allow Eval action to settle`
    )
    await new Promise(resolve => setTimeout(resolve, initDelayMs))
    console.info('Initializing with Action: Init')
    const { messageId, result } = await sendAosMessage({
      processId,
      data: initData,
      signer: signer as any,
      tags: [{ name: 'Action', value: 'Init' }]
    })

    if (result.Error) {
      console.error('Init Action resulted in an error', result.Error)
    } else {
      console.info(`Init Action successful with message id ${messageId}`)
    }
  } else {
    console.info('CALL_INIT_HANDLER is not set to "true", skipping INIT')
  }

  console.info(
    `Deployment of ${processName} complete!`
      + ` Check the deployed process in your browser at`
      + ` https://aolink.arweave.net/#/entity/${processId}`
  )
}

deploy().catch(e => { console.error(e); process.exit(1); })
