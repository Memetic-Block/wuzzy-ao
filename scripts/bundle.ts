import path from 'path'
import fs from 'fs'

import { logger } from './util/logger'
import { bundleLua } from './util/lua-bundler'

const CONTRACT_NAMES = process.env.CONTRACT_NAMES
  ? process.env.CONTRACT_NAMES.split(',')
  : fs.readdirSync(path.join(path.resolve(), './dist'))

async function bundle() {
  const contracts = [
    { path: 'acl-test', name: 'acl-test' },
    { path: 'wuzzy-crawler', name: 'wuzzy-crawler', stringifySource: true },
    { path: 'wuzzy-nest', name: 'wuzzy-nest', stringifySource: true },
    { path: 'weavedrive-test', name: 'weavedrive-test' },
    { path: 'wuzzy-tx-oracle-test', name: 'wuzzy-tx-oracle-test' },
    { path: 'wuzzy-nest-registry', name: 'wuzzy-nest-registry' },
    { path: 'relay-test', name: 'relay-test' }
  ]

  logger.info(
    `Bundling ${contracts.length} ` +
      `contracts: ${contracts.map(c => c.name).join(',')}`
  )

  for (const contract of contracts) {
    if (!CONTRACT_NAMES.includes(contract.name)) {
      logger.info(`Skipping bundling lua for ${contract.name}...`)
      continue
    }

    logger.info(`Bundling Lua for ${contract.name}...`)

    const luaEntryPath = path.join(
      path.resolve(),
      `./src/contracts/${contract.path}/${contract.name}.lua`
    )
    if (!fs.existsSync(luaEntryPath)) {
      throw new Error(`Lua entry path not found: ${luaEntryPath}`)
    }

    const bundledLua = bundleLua(luaEntryPath)
    if (!fs.existsSync(path.join(path.resolve(), `./dist/${contract.path}`))) {
      fs.mkdirSync(
        path.join(path.resolve(), `./dist/${contract.path}`),
        { recursive: true }
      )
    }
    fs.writeFileSync(
      path.join(path.resolve(), `./dist/${contract.path}/process.lua`),
      bundledLua
    )

    fs.copyFileSync('./src/lib/hyper-aos.lua', `./dist/${contract.path}/ao.lua`)

    if (contract.stringifySource) {
      const base64Code = Buffer.from(bundledLua, 'utf-8').toString('base64')
      const stringifiedSource =
        `local CodeString = '${base64Code}'\nreturn CodeString`
      fs.writeFileSync(
        path.join(
          path.resolve(),
          `./src/contracts/${contract.path}/${contract.name}-stringified.lua`
        ),
        stringifiedSource
      )
    }

    logger.info(`Done Bundling Lua for ${contract.name}!`)
  }
}

bundle()
  .then()
  .catch(err => logger.error(`Error bundling Lua: ${err.message}`, err.stack))
