import path from 'path'
import fs from 'fs'

import { bundleLua } from './util/lua-bundler'

const logger = console

const CONTRACT_NAMES = process.env.CONTRACT_NAMES
  ? process.env.CONTRACT_NAMES.split(',')
  : fs.readdirSync(path.join(path.resolve(), './src/legacynet'))
      .filter(name => {
        const stat = fs.statSync(path.join(path.resolve(), './src/legacynet', name))
        return stat.isDirectory() && !['common', 'lib'].includes(name)
      })

async function bundle() {
  const contracts = [
    { path: 'wuzzy-nest', name: 'wuzzy-nest', stringifySource: true }
  ]

  logger.info(
    `Bundling ${contracts.length} legacynet ` +
      `contracts: ${contracts.map(c => c.name).join(',')}`
  )

  for (const contract of contracts) {
    if (!CONTRACT_NAMES.includes(contract.path)) {
      logger.info(`Skipping bundling lua for ${contract.name}...`)
      continue
    }

    logger.info(`Bundling Lua for legacynet/${contract.name}...`)

    const luaEntryPath = path.join(
      path.resolve(),
      `./src/legacynet/${contract.path}/${contract.name}.lua`
    )
    if (!fs.existsSync(luaEntryPath)) {
      throw new Error(`Lua entry path not found: ${luaEntryPath}`)
    }

    const bundledLua = bundleLua(luaEntryPath)
    const distDir = path.join(path.resolve(), `./dist/legacynet/${contract.path}`)
    if (!fs.existsSync(distDir)) {
      fs.mkdirSync(distDir, { recursive: true })
    }
    fs.writeFileSync(
      path.join(distDir, 'process.lua'),
      bundledLua
    )

    if (contract.stringifySource) {
      const base64Code = Buffer.from(bundledLua, 'utf-8').toString('base64')
      const stringifiedSource =
        `local CodeString = '${base64Code}'\nreturn CodeString`
      fs.writeFileSync(
        path.join(
          path.resolve(),
          `./src/legacynet/${contract.path}/${contract.name}-stringified.lua`
        ),
        stringifiedSource
      )
    }

    logger.info(`Done Bundling Lua for legacynet/${contract.name}!`)
  }
}

bundle()
  .then()
  .catch(err => logger.error(`Error bundling Lua: ${err.message}`, err.stack))
