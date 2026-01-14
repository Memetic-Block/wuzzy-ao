import 'dotenv/config'
import { readFileSync } from 'fs'
import { join, resolve } from 'path'
import { JWKInterface } from '@ardrive/turbo-sdk/lib/types/common/jwk'
import { createDataItemSigner, spawn as AoSpawn } from '@permaweb/aoconnect'
import { logger } from './util/logger'
import { sendAosMessage } from './util/send-aos-message'

const messagingUnitAddress = process.env.MESSAGING_UNIT_ADDRESS ||
  'fcoN_xJeisVsPXA-trzVAuIiqO3ydLQxM-L4XbrQKzY'
const schedulerUnitAddress = process.env.SCHEDULER_UNIT_ADDRESS ||
  '_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA'
const aosModuleId = process.env.AOS_MODULE_ID ||
  'QEgxNlbNwBi10VXu5DbP6XHoRDHcynP_Qbq3lpNC97s'

const CONTRACT_NAME = process.env.CONTRACT_NAME || ''
if (!CONTRACT_NAME) {
  throw new Error('CONTRACT_NAME is not set! Example: CONTRACT_NAME=wuzzy-nest')
}
const LUA_SOURCE_TXID = process.env.LUA_SOURCE_TX_ID || ''
if (!LUA_SOURCE_TXID) {
  throw new Error('LUA_SOURCE_TX_ID is not set!')
}
const PRIVATE_KEY = process.env.PRIVATE_KEY || ''
if (!PRIVATE_KEY) {
  throw new Error('PRIVATE_KEY is not set!')
}
const JWK = JSON.parse(readFileSync(PRIVATE_KEY, 'utf-8'))

const SPAWN_TAGS = JSON.parse(process.env.SPAWN_TAGS || '[]')
if (!Array.isArray(SPAWN_TAGS)) {
  throw new Error('SPAWN_TAGS must be a JSON array!')
}

export async function spawn(
  contractName: string,
  luaSourceTxId: string,
  arweaveWalletJwk: JWKInterface,
  spawnTags?: { name: string; value: string }[]
) {
  logger.info(`Spawning new AO Legacynet Process for [${contractName}]`)
  logger.info(`Using LUA Source TX ID [${luaSourceTxId}]`)
  logger.info(`Using AO Module ID [${aosModuleId}]`)
  logger.info(`Using Scheduler Unit Address [${schedulerUnitAddress}]`)
  logger.info(`Using Messaging Unit Address [${messagingUnitAddress}]`)
  logger.info(`Using Deployer Public Key [${arweaveWalletJwk.n}]`)
  const signer = createDataItemSigner(arweaveWalletJwk)

  logger.info(`Spawning new AO Legacynet Process...`)
  if (spawnTags && spawnTags.length > 0) {
    logger.info(`With additional spawn tags: ${JSON.stringify(spawnTags)}`)
  }
  const processId = await AoSpawn({
    module: aosModuleId,
    scheduler: schedulerUnitAddress,
    signer,
    tags: [
      { name: 'App-Name', value: 'Wuzzy' },
      { name: 'Contract-Name', value: contractName },
      { name: 'Authority', value: messagingUnitAddress },
      { name: 'Timestamp', value: Date.now().toString() },
      { name: 'Network', value: 'legacynet' },
      {
        name: 'Source-Code-TX-ID',
        value: luaSourceTxId
      },
      ...(spawnTags || [])
    ]
  })

  logger.info(`Sending EVAL of [${contractName}] to AO Legacynet Process [${processId}]`)
  
  // Read the bundled legacynet contract
  const contractPath = join(resolve(), `./dist/legacynet/${contractName}/process.lua`)
  await sendAosMessage({
    processId,
    data: readFileSync(contractPath, 'utf8'),
    signer,
    tags: [
      { name: 'Action', value: 'Eval' },
      { name: 'App-Name', value: 'Wuzzy' },
      {
        name: 'Source-Code-TX-ID',
        value: luaSourceTxId
      }
    ]
  })

  logger.info(
    `Legacynet process spawned & EVAL action sent for [${contractName}] at [${processId}]`
  )
  
  return processId
}

spawn(CONTRACT_NAME, LUA_SOURCE_TXID, JWK, SPAWN_TAGS).then((processId) => {
  logger.info(`Spawn AO Legacynet Process executed successfully!`)
  logger.info(`Process ID: ${processId}`)
}).catch(error => {
  logger.error(`Error executing spawn AO Legacynet Process:`, error)
  process.exit(1)
})
