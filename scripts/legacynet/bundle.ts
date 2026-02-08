import path from 'path'
import fs from 'fs'

import { bundleLua } from '../util/lua-bundler'

const CONTRACT_NAMES = process.env.CONTRACT_NAMES
  ? process.env.CONTRACT_NAMES.split(',')
  : fs.readdirSync(path.join(path.resolve(), './src/legacynet'))

async function bundle() {
  const contracts = [
    { path: 'wuzzy-nest', name: 'wuzzy-nest' },
    { path: 'wuzzy-nest-registry', name: 'wuzzy-nest-registry' },
  ]

  console.info(
    `Bundling ${contracts.length} ` +
      `contracts: ${contracts.map(c => c.name).join(',')}`
  )

  for (const contract of contracts) {
    if (!CONTRACT_NAMES.includes(contract.name)) {
      console.info(`Skipping bundling lua for ${contract.name}...`, CONTRACT_NAMES)

      continue
    }

    console.info(`Bundling Lua for ${contract.name}...`)

    const luaEntryPath = path.join(
      path.resolve(),
      `./src/legacynet/${contract.path}/${contract.name}.lua`
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

    console.info(`Done Bundling Lua for ${contract.name}!`)
  }
}

bundle()
  .then()
  .catch(err => console.error(`Error bundling Lua: ${err.message}`, err.stack))