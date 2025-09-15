import 'dotenv/config'
import { readFileSync } from 'fs'
import { connect, createSigner } from '@permaweb/aoconnect'
import Arweave from 'arweave'

import { logger } from './util/logger'

const HYPERBEAM_URL = process.env.HYPERBEAM_URL || 'https://forward.computer'
const SCHEDULER = process.env.SCHEDULER
  || 'NoZH3pueH0Cih6zjSNu_KRAcmg4ZJV1aGHKi0Pi5_Hc'
const AUTHORITY = process.env.AUTHORITY
  || 'QWg43UIcJhkdZq6ourr1VbnkwcP762Lppd569bKWYKY'
const PRIVATE_KEY = process.env.PRIVATE_KEY || ''
if (!PRIVATE_KEY) {
  throw new Error('PRIVATE_KEY is not set!')
}
const wallet = JSON.parse(readFileSync(PRIVATE_KEY, 'utf-8'))

const MODULE = process.env.MODULE
  || 'xVcnPK8MPmcocS6zwq1eLmM2KhfyarP8zzmz3UVi1g4'
const NAME = process.env.PROCESS_NAME
const GATEWAY = process.env.GATEWAY || 'https://arweave.net'

async function spawn() {
  const address = await Arweave.init({}).wallets.getAddress(wallet)
  logger.info(`Spawning new hyper-aos process [${NAME || 'unnamed'}]`)
  logger.info(`Wallet = [${address}]`)
  logger.info(`Scheduler = [${SCHEDULER}]`)
  logger.info(`Authority = [${AUTHORITY}]`)
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
  const spawnParams = {
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
    'app-name': 'hyper-aos',
    name: NAME,
    scheduler: SCHEDULER,
    authority: `${AUTHORITY},fcoN_xJeisVsPXA-trzVAuIiqO3ydLQxM-L4XbrQKzY`,
    module: MODULE
  }
  const spawnResult = await request(spawnParams) as Awaited<
    ReturnType<typeof request>
  > & { process: string }
  logger.info(`Spawn result: [${spawnResult.status}]`)
  logger.info(`Spawned process id: [${spawnResult.process}]`)

  const evalParams = {
    type: 'Message',
    path: `/${spawnResult.process}/push`,
    method: 'POST',
    action: 'Eval',
    'data-protocol': 'ao',
    target: spawnResult.process,
    'signing-format': 'ANS-104',
    accept: 'application/json',
    data: 'require(".process")._version'
  }
  const evalResult = await request(evalParams)
  logger.info(`Eval result: [${JSON.stringify(evalResult)}]`)
}

spawn().then(() => {
  logger.info('Spawn AO Process executed successfully!')
}).catch(error => {
  logger.error(`Error executing spawn AO Process:`, error)
  process.exit(1)
})
