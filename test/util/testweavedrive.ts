import fs from 'fs'
import path from 'path'
import AoLoader from '@permaweb/ao-loader'
import weaveDrive from './weavedrive.js'

const Module = {
  Id: 'MODULE',
  Owner: 'OWNER',
  Tags: [
    { name: 'Data-Protocol', value: 'ao' },
    { name: 'Variant', value: 'ao.TN.1' },
    { name: 'Type', value: 'Module' },
    { name: 'Authority', value: 'PROCESS' }
  ]
}

const Process = {
  Id: 'PROCESS',
  Owner: 'PROCESS',
  Tags: [
    { name: 'Data-Protocol', value: 'ao' },
    { name: 'Variant', value: 'ao.TN.1' },
    { name: 'Type', value: 'Process' },
    { name: 'Extension', value: 'WeaveDrive' },
    { name: 'Module', value: 'MODULE' },
    { name: 'Authority', value: 'PROCESS' }
  ]
}

const Msg = {
  Id: 'MESSAGE',
  Owner: 'PROCESS',
  From: 'PROCESS',
  Target: 'PROCESS',
  Module: 'MODULE',
  Tags: [
    { name: 'Data-Protocol', value: 'ao' },
    { name: 'Variant', value: 'ao.TN.1' },
    { name: 'Type', value: 'Message' },
    { name: 'Action', value: 'Eval' }
  ],
  'Block-Height': 1000,
  Timestamp: Date.now()
}

const options = {
  format: 'wasm32-unknown-emscripten-metering',//'wasm64-unknown-emscripten-draft_2024_02_15',
  WeaveDrive: weaveDrive,
  ARWEAVE: 'https://arweave.net',
  mode: 'test',
  blockHeight: 1000,
  spawn: {
    tags: Process.Tags
  },
  module: {
    tags: Module.Tags
  }
}
const TX_ID_TO_LOAD = 'iaiAqmcYrviugZq9biUZKJIAi_zIT_mgFHAWZzMvDuk'
const blockHeight = 1536315
const mode = 'Assignments'
const ProcessAssignmentsMode = {
  Id: 'PROCESS',
  Owner: 'PROCESS',
  Target: 'PROCESS',
  Tags: [
    { name: 'Data-Protocol', value: 'ao' },
    { name: 'Variant', value: 'ao.TN.1' },
    { name: 'Type', value: 'Process' },
    { name: 'Extension', value: 'WeaveDrive' },
    { name: 'Module', value: 'MODULE' },
    { name: 'Authority', value: 'PROCESS' },
    { name: 'Availability-Type', value: mode }
  ],
  Data: 'Test = 1',
  From: 'PROCESS',
  Module: 'MODULE',
  'Block-Height': 4567,
  Timestamp: Date.now()
}

const ProcessSchedulerAttested = {
  ...ProcessAssignmentsMode,
  Tags: [
    ...ProcessAssignmentsMode.Tags,
    { name: 'Scheduler', value: 'kdUCABg56Jroco1kMwfF-YIjah9wBbZ1BhyOnwLwOY0' }
  ]
}

async function testweavedrive() {
  let memory: ArrayBuffer | null = null
  console.log('cwd', process.cwd(), __dirname)
  const wasm = fs.readFileSync(process.cwd()+'/test/util/nEjlSFA_8narJlVHApbczDPkMc9znSqYtqtf1iOdoxM.wasm')
  const drive = fs.readFileSync(process.cwd()+'/src/contracts/common/weavedrive.lua', 'utf-8')
  const handle = await AoLoader(wasm, options)
  const result = await handle(memory, {
    ...Msg,
    Data: `
local function _load()
  ${drive}
end
_G.package.loaded['WeaveDrive'] = _load()
return "ok"
`
    }, { Process, Module }
  )
  console.log('Load WeaveDrive result:', JSON.stringify({
    Assignments: result.Assignments,
    Messages: result.Messages,
    Output: result.Output,
    Patches: result.Patches,
    Spawns: result.Spawns
  }, null, 2))

  const handle2 = await AoLoader(wasm, {
    ...options,
    spawn: {
      id: ProcessSchedulerAttested.Id,
      owner: ProcessSchedulerAttested.Owner,
      tags: ProcessSchedulerAttested.Tags
    },
    mode
  })
  const result2 = await handle(null, {
    ...Msg,
    'Block-Height': blockHeight + 2,
    Data: `
      local function _load() ${drive} end
      _G.package.loaded['WeaveDrive'] = _load()
      local drive = require('WeaveDrive')
      local tx = drive.getTx("${TX_ID_TO_LOAD}")
      local txData = drive.getData("${TX_ID_TO_LOAD}")
      return require('json').encode({
        tx = tx,
        data = tostring(txData)
      })
    `
  }, { Process: ProcessSchedulerAttested, Module })
  console.log('drive.getData result:', JSON.stringify({
    Assignments: result2.Assignments,
    Messages: result2.Messages,
    Output: result2.Output,
    Patches: result2.Patches,
    Spawns: result2.Spawns
  }, null, 2))
}

testweavedrive()
  .then(() => {
    console.log('Test Weave Drive completed successfully.')
  })
  .catch((error) => {
    console.error('Error during Test Weave Drive:', error)
    process.exit(1)
  })
