import 'dotenv/config'
import { createReadStream, readFileSync, statSync } from 'fs'
import { ArweaveSigner, TurboFactory, TurboSigner } from '@ardrive/turbo-sdk'
import { logger } from './util/logger'

const CONTRACT_VERSION = process.env.CONTRACT_VERSION || 'dev'
const CONTRACT_NAME = process.env.CONTRACT_NAME || ''
if (!CONTRACT_NAME) {
  throw new Error('CONTRACT_NAME is not set!')
}
const PRIVATE_KEY = process.env.PRIVATE_KEY || ''
if (!PRIVATE_KEY) {
  throw new Error('PRIVATE_KEY is not set!')
}
const JWK = JSON.parse(readFileSync(PRIVATE_KEY, 'utf-8'))
const SIGNER = new ArweaveSigner(JWK)

export async function publish(
  contractName: string,
  contractVersion: string,
  signer: TurboSigner
) {
  logger.info(`Publishing AO Process LUA Source for [${contractName}]`)
  logger.info(`Using contract version: ${contractVersion}`)
  const bundledLuaPath = `./dist/${contractName}.lua`
  const bundledLuaSize = statSync(bundledLuaPath).size
  const turbo = TurboFactory.authenticated({ signer })
  const uploadResult = await turbo.uploadFile({
    fileStreamFactory: () => createReadStream(bundledLuaPath),
    fileSizeFactory: () => bundledLuaSize,
    dataItemOpts: {
      tags: [
        { name: 'App-Name', value: 'aos-LUA' },
        { name: 'App-Version', value: '0.0.1' },
        { name: 'Content-Type', value: 'text/x-lua' },
        { name: 'Author', value: 'Memetic Block' },
        { name: 'Contract-Name', value: contractName },
        { name: 'Nonce', value: new Date().getTime().toString() },
        { name: 'Version', value: contractVersion }
      ]
    }
  })

  logger.info(
    `Publish ${contractName} source result: ${JSON.stringify(uploadResult)}`
  )
}

publish(CONTRACT_NAME, CONTRACT_VERSION, SIGNER).then(() => {
  logger.info('Publish contract script executed successfully!')
}).catch(error => {
  logger.error(
    `Error executing publish contract script: ${error.message}`,
    error.stack
  )
  process.exit(1)
})
