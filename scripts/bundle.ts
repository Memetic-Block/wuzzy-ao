import path from 'path'
import fs from 'fs'

import { logger } from './util/logger'
import { bundleLua } from './util/lua-bundler'

async function bundle() {
  const contracts = [
    { path: 'acl-test', name: 'acl-test' },
    { path: 'wuzzy-crawler', name: 'wuzzy-crawler' },
    { path: 'wuzzy-nest', name: 'wuzzy-nest' }
  ]

  logger.info(
    `Bundling ${contracts.length} ` +
      `contracts: ${contracts.map(c => c.name).join(',')}`
  )

  for (const contract of contracts) {
    logger.info(`Bundling Lua for ${contract.name}...`)

    const luaEntryPath = path.join(
      path.resolve(),
      `./src/contracts/${contract.path}/${contract.name}.lua`
    )
    if (!fs.existsSync(luaEntryPath)) {
      throw new Error(`Lua entry path not found: ${luaEntryPath}`)
    }

    const bundledLua = bundleLua(luaEntryPath)
    if (!fs.existsSync(path.join(path.resolve(), `./dist`))) {
      fs.mkdirSync(
        path.join(path.resolve(), `./dist`),
        { recursive: true }
      )
    }
    fs.writeFileSync(
      path.join(path.resolve(), `./dist/${contract.name}.lua`),
      bundledLua
    )

    logger.info(`Done Bundling Lua for ${contract.name}!`)
  }
}

bundle()
  .then()
  .catch(err => logger.error(`Error bundling Lua: ${err.message}`, err.stack))
