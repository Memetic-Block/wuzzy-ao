import 'dotenv/config'
import { readFileSync } from 'fs'
import { connect, createSigner } from '@permaweb/aoconnect'
import Arweave from 'arweave'

// import { logger } from './util/logger'
const logger = console

const HYPERBEAM_URL = process.env.HYPERBEAM_URL || 'https://forward.computer'
const PRIVATE_KEY = process.env.PRIVATE_KEY || ''
if (!PRIVATE_KEY) {
  throw new Error('PRIVATE_KEY is not set!')
}
const wallet = JSON.parse(readFileSync(PRIVATE_KEY, 'utf-8'))

const MODULE = process.env.MODULE
  || 'xVcnPK8MPmcocS6zwq1eLmM2KhfyarP8zzmz3UVi1g4'
const NAME = process.env.PROCESS_NAME
const GATEWAY = process.env.GATEWAY || 'https://arweave.net'

// Functions to dynamically resolve scheduler and authority (like AOS CLI does)
async function setScheduler(ctx: any) {
  let scheduler = process.env.SCHEDULER
  if (scheduler === "undefined" || scheduler === undefined) {
    let schedulerUrl = HYPERBEAM_URL
    if (schedulerUrl === 'https://forward.computer') {
      schedulerUrl = 'https://scheduler.forward.computer'
    }
    scheduler = await fetch(schedulerUrl + '/~meta@1.0/info/address')
      .then(r => r.text())
  }
  ctx['scheduler'] = scheduler
  return ctx
}

async function setAuthority(ctx: any) {
  let authority = process.env.AUTHORITY

  if (authority === "undefined" || authority === undefined) {
    if (HYPERBEAM_URL === 'https://forward.computer') {
      authority = "QWg43UIcJhkdZq6ourr1VbnkwcP762Lppd569bKWYKY"
    } else {
      authority = await fetch(HYPERBEAM_URL + '/~meta@1.0/info/address')
        .then(r => r.text())
    }
    authority = authority + ',fcoN_xJeisVsPXA-trzVAuIiqO3ydLQxM-L4XbrQKzY'
  }
  ctx['authority'] = authority
  return ctx
}

async function spawn() {
  const address = await Arweave.init({}).wallets.getAddress(wallet)
  logger.info(`Spawning new hyper-aos process [${NAME || 'unnamed'}]`)
  logger.info(`Wallet = [${address}]`)
  logger.info(`Module = [${MODULE}]`)
  logger.info(`Gateway = [${GATEWAY}]`)
  logger.info(`Hyperbeam = [${HYPERBEAM_URL}]`)

  const { request } = connect({
    MODE: 'mainnet',
    device: 'process@1.0',
    signer: createSigner(wallet),
    GATEWAY_URL: GATEWAY,
    URL: HYPERBEAM_URL
  })

  // Build spawn parameters like AOS CLI does
  let spawnParams: any = {
    path: '/push',
    method: 'POST',
    type: 'Process',
    device: 'process@1.0',
    'scheduler-device': 'scheduler@1.0',
    'push-device': 'push@1.0',
    'execution-device': 'lua@5.3a',
    'data-protocol': 'ao',
    variant: 'ao.N.1',
    'signing-format': 'ANS-104',
    'aos-version': '2.0.8',
    'accept-bundle': 'true',
    'codec-device': 'ans104@1.0',
    module: MODULE,
    ...(NAME && { name: NAME })
  }

  // Set scheduler and authority dynamically like AOS CLI
  spawnParams = await setScheduler(spawnParams)
  spawnParams = await setAuthority(spawnParams)

  logger.info('Spawn parameters:', JSON.stringify(spawnParams, null, 2))

  const spawnResult = await request(spawnParams) as Awaited<
    ReturnType<typeof request>
  > & { process: string }
  
  logger.info(`Full spawn result:`, JSON.stringify(spawnResult, null, 2))
  logger.info(`Spawn result: [${spawnResult.status}]`)
  logger.info(`Spawned process id: [${spawnResult.process}]`)

  // Check if process was created successfully
  if (!spawnResult.process) {
    throw new Error('Failed to spawn process - no process ID returned')
  }
}

spawn().then(() => {
  logger.info('✅ Spawn AO Process executed successfully!')
}).catch(error => {
  // Check if this is actually a successful response disguised as an error
  if (error.message && (error.message.includes('print: true') || error.message.includes('prompt:'))) {
    console.log('error.message', error.message)
    process.exit(0)
  } else {
    logger.error(`❌ Error executing spawn AO Process:`, error)
    process.exit(1)
  }
})
