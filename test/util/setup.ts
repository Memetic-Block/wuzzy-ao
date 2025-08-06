import fs from 'fs'
import path from 'path'
import AoLoader from '@permaweb/ao-loader'
import MockTransactions from '~/test/util/mock-transactions.json'

export const MODULE_NAME = 'Wuzzy'
export const OWNER_ADDRESS = ''.padEnd(42, '1')
export const ALICE_ADDRESS = ''.padEnd(42, 'A')
export const BOB_ADDRESS = ''.padEnd(42, 'B')
export const CHARLS_ADDRESS = ''.padEnd(42, 'C')
export const PROCESS_ID = ''.padEnd(43, '2')
export const MODULE_ID = ''.padEnd(43, '3')
export const DEFAULT_MODULE_ID = ''.padEnd(43, '4')
export const DEFAULT_TARGET = ''.padEnd(43, '5')
export const DEFAULT_MESSAGE_ID = ''.padEnd(43, 'f')
export const NEST_ID = 'nest_'.padEnd(43, '0')
export const ARIO_NETWORK_PROCESS_ID = 'ario_network_process_'.padEnd(43, '0')
export const ANT_PROCESS_ID = 'ant_process_'.padEnd(43, '0')

export const AO_ENV = {
  Process: {
    Id: PROCESS_ID,
    Owner: OWNER_ADDRESS,
    Tags: [
      { name: 'Authority', value: OWNER_ADDRESS }
    ]
  },
  Module: {
    Id: MODULE_ID,
    Owner: OWNER_ADDRESS,
    Tags: [
      { name: 'Authority', value: OWNER_ADDRESS }
    ]
  }
}

const AOS_WASM = fs.readFileSync(
  path.join(
    path.resolve(),
    // './test/util/aos-cbn0KKrBZH7hdNkNokuXLtGryrWM--PjSTBqIzw9Kkk.wasm'
    // './test/util/aos-Pq2Zftrqut0hdisH_MC2pDOT6S4eQFoxGsFUzR6r350.wasm'
    // './test/util/aos64.wasm'
    './test/util/QEgxNlbNwBi10VXu5DbP6XHoRDHcynP_Qbq3lpNC97s.wasm'
    // './test/util/nEjlSFA_8narJlVHApbczDPkMc9znSqYtqtf1iOdoxM.wasm'
  )
)
const AOS_WASM_FORMAT = 'wasm64-unknown-emscripten-draft_2024_02_15'
// const AOS_WASM_FORMAT = 'wasm32-unknown-emscripten-metering'

export const DEFAULT_HANDLE_OPTIONS = {
  Id: DEFAULT_MESSAGE_ID,
  ['Block-Height']: '1',
  // NB: Important to set the address so that that `Authority` check passes.
  //     Else the `isTrusted` with throw an error.
  Owner: OWNER_ADDRESS,
  Module: MODULE_ID,
  Target: PROCESS_ID,// Target: DEFAULT_TARGET,
  Timestamp: Date.now().toString(),
  Tags: [],
  Cron: false,
  From: OWNER_ADDRESS,
  Reference: '1'
}

// NB: Preload bundled contract source as a simple in-memory cache
const contractNames = [
  'acl-test',
  'wuzzy-crawler',
  'wuzzy-nest'
]
const bundledContractSources = Object.fromEntries(contractNames.map(cn => [
  cn,
  fs.readFileSync(path.join(path.resolve(), `./dist/${cn}.lua`), 'utf-8')
]))

export type FullAOHandleFunction = (
  buffer: ArrayBuffer | null,
  msg: AoLoader.Message,
  env: AoLoader.Environment
) => Promise<AoLoader.HandleResponse & { Error?: string }>

export type AOTestHandle = (
  options?: Partial<AoLoader.Message>,
  mem?: ArrayBuffer | null
) => Promise<AoLoader.HandleResponse & { Error?: string }>

export type AOCreateLoaderOptions = {
  contractSource?: string,
  processTags?: AoLoader.Tag[],
  useWeaveDriveMock?: boolean
}

const WEAVEDRIVE_MOD_HEADER = '-- module: "..common.weavedrive"'
const WEAVEDRIVE_MOD_FOOTER = '_G.package.loaded["..common.weavedrive"] = _loaded_mod__common_weavedrive()'
const MOCK_WEAVEDRIVE_SRC = fs.readFileSync(
  path.join(path.resolve(), './test/util/mockweavedrive.lua'),
  'utf-8'
)
let mockWeavedriveTxs = 'local MOCK_WEAVEDRIVE_TXS = {\n'
let mockWeavedriveData = 'local MOCK_WEAVEDRIVE_DATA = {\n'
for (const { tx, data } of MockTransactions) {
  mockWeavedriveTxs += `['${tx.id}'] = '${JSON.stringify(tx)}',\n`
  mockWeavedriveData += `['${tx.id}'] = '${data}',\n`
}
mockWeavedriveTxs += '}\n'
mockWeavedriveData += '}\n'
const weaveDriveMock = MOCK_WEAVEDRIVE_SRC
  .replace('local MOCK_WEAVEDRIVE_TXS = {}', mockWeavedriveTxs)
  .replace('local MOCK_WEAVEDRIVE_DATA = {}', mockWeavedriveData)
export async function createLoader(
  contractName: string,
  options: AOCreateLoaderOptions = {}
) {
  const originalHandle = await AoLoader(AOS_WASM, {
    format: AOS_WASM_FORMAT,
    memoryLimit: '524288000', // in bytes
    computeLimit: 9e12,
    extensions: []
  })

  if (!bundledContractSources[contractName] && !options.contractSource) {
    throw new Error(`Unknown contract: ${contractName}`)
  }

  const programs = [
    {
      action: 'Eval',
      args: [{ name: 'Module', value: DEFAULT_MODULE_ID }],
      Data: options.contractSource || bundledContractSources[contractName]
    }
  ]
  let memory: ArrayBuffer | null = null
  for (const { action, args, Data } of programs) {
    let evalData = Data

    const includesWeaveDriveHeader = Data.includes(WEAVEDRIVE_MOD_HEADER)
    if (options.useWeaveDriveMock && includesWeaveDriveHeader) {
      const first = Data.split(WEAVEDRIVE_MOD_HEADER)
      const second = first[1].split(WEAVEDRIVE_MOD_FOOTER)
      evalData = `${first[0]}${weaveDriveMock}${second[1]}`
    }

    const result = await originalHandle(
        memory,
        {
          ...DEFAULT_HANDLE_OPTIONS,
          Tags: [
            ...args,
            { name: 'Action', value: action }
          ],
          Data: evalData,
          // From: AO_ENV.Process.Id
        },
        {
          ...AO_ENV,
          Process: {
            Id: AO_ENV.Process.Id,
            Owner: AO_ENV.Process.Owner,
            Tags: [
              ...AO_ENV.Process.Tags,
              ...(options.processTags || [])
            ],
          }
        }
      )
    // console.log(`DEBUG - AO EVAL Result `, JSON.stringify({
    //   Assignments: result.Assignments,
    //   Messages: result.Messages,
    //   Output: result.Output,
    //   Patches: result.Patches,
    //   Spawns: result.Spawns
    // }, null, 2))
  }

  async function handle(
    options: Partial<AoLoader.Message> = {},
    mem = memory
  ) {
    const result = await originalHandle(
      mem,
      {
        ...DEFAULT_HANDLE_OPTIONS,
        ...options,
      },
      AO_ENV
    )

    // console.log(
    //   `DEBUG - AO Message Result `,
    //   JSON.stringify(
    //     // Object.keys(result),
    //     {
    //       Assignments: result.Assignments,
    //       Messages: result.Messages,
    //       Output: result.Output,
    //       Patches: result.Patches,
    //       Spawns: result.Spawns
    //     },
    //     null,
    //     2
    //   )
    // )

    // NB: ao-loader isn't updated for this aos wasm, so stitch Error back in
    if (
      (result.Output?.data as string || '').startsWith('\x1B[31mError\x1B[90m')
    ) {
      result.Error = result.Output.data
    }

    return result
  }

  return {
    handle,
    originalHandle,
    memory: memory as unknown as ArrayBuffer
  }
}
