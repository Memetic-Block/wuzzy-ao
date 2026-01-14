import fs from 'fs'
import path from 'path'
import AoLoader from '@permaweb/ao-loader'

// Test addresses
export const OWNER_ADDRESS = '0x'.padEnd(42, '1')
export const ALICE_ADDRESS = '0x'.padEnd(42, 'A')
export const BOB_ADDRESS = '0x'.padEnd(42, 'B')
export const CHARLS_ADDRESS = '0x'.padEnd(42, 'C')
export const PROCESS_ID = ''.padEnd(43, '2')
export const MODULE_ID = ''.padEnd(43, '3')
export const DEFAULT_MODULE_ID = ''.padEnd(43, '4')
export const DEFAULT_TARGET = ''.padEnd(43, '5')
export const DEFAULT_MESSAGE_ID = ''.padEnd(43, 'f')

// Crawler IDs for testing
export const CRAWLER_A = ''.padEnd(43, 'A')
export const CRAWLER_B = ''.padEnd(43, 'B')

// AO Environment configuration for legacynet
export const AO_ENV = {
  Process: {
    Id: PROCESS_ID,
    Owner: OWNER_ADDRESS,
    Tags: [
      { name: 'Authority', value: 'XXXXXX' }
    ],
  },
  Module: {
    Id: MODULE_ID,
    Owner: OWNER_ADDRESS,
    Tags: [
      { name: 'Authority', value: 'YYYYYY' }
    ],
  }
}

// Load the AOS WASM for legacynet testing
// Download from: https://arweave.net/Pq2Zftrqut0hdisH_MC2pDOT6S4eQFoxGsFUzR6r350
const AOS_WASM_PATH = path.join(
  path.resolve(),
  './test/legacynet/util/aos64.wasm'
)

let AOS_WASM: Buffer | null = null
try {
  AOS_WASM = fs.readFileSync(AOS_WASM_PATH)
} catch (err) {
  console.warn(
    `Warning: aos64.wasm not found at ${AOS_WASM_PATH}. ` +
    `Download it from https://arweave.net/Pq2Zftrqut0hdisH_MC2pDOT6S4eQFoxGsFUzR6r350`
  )
}

// Default message options
export const DEFAULT_HANDLE_OPTIONS = {
  Id: DEFAULT_MESSAGE_ID,
  ['Block-Height']: '1',
  Owner: OWNER_ADDRESS,
  Module: MODULE_ID,
  Target: DEFAULT_TARGET,
  From: OWNER_ADDRESS,
  Timestamp: Date.now().toString(),
  Tags: [] as { name: string; value: string }[]
}

// Pre-load bundled contract sources
const contractNames = ['wuzzy-nest']
const bundledContractSources: Record<string, string> = {}

for (const contractName of contractNames) {
  const contractPath = path.join(
    path.resolve(),
    `./dist/legacynet/${contractName}/process.lua`
  )
  try {
    bundledContractSources[contractName] = fs.readFileSync(contractPath, 'utf-8')
  } catch (err) {
    console.warn(`Warning: Contract not bundled: ${contractName}. Run 'npm run bundle:legacynet' first.`)
  }
}

export type FullAOHandleFunction = (
  buffer: ArrayBuffer | null,
  msg: AoLoader.Message,
  env: AoLoader.Environment
) => Promise<AoLoader.HandleResponse & { Error?: string }>

export type AOTestHandle = (
  options?: Partial<AoLoader.Message>,
  mem?: ArrayBuffer | null
) => Promise<AoLoader.HandleResponse & { Error?: string }>

/**
 * Creates a loader for testing legacynet contracts
 * @param contractName The name of the contract to load
 * @param contractSource Optional custom contract source (for testing modifications)
 * @returns An object with the handle function and memory
 */
export async function createLoader(
  contractName: string,
  contractSource?: string
): Promise<{ handle: AOTestHandle; originalHandle: FullAOHandleFunction; memory: ArrayBuffer }> {
  if (!AOS_WASM) {
    throw new Error(
      `aos64.wasm not found. Download it from https://arweave.net/Pq2Zftrqut0hdisH_MC2pDOT6S4eQFoxGsFUzR6r350 ` +
      `and place it at ${AOS_WASM_PATH}`
    )
  }

  const originalHandle = await AoLoader(AOS_WASM, {
    format: 'wasm64-unknown-emscripten-draft_2024_02_15',
    memoryLimit: '524288000', // in bytes
    computeLimit: 9e12,
    extensions: []
  })

  if (!bundledContractSources[contractName] && !contractSource) {
    throw new Error(
      `Unknown contract: ${contractName}. ` +
      `Run 'npm run bundle:legacynet' first or provide contractSource.`
    )
  }

  // Initialize memory by evaluating the contract source
  let memory: ArrayBuffer | null = null
  const evalResult = await originalHandle(
    memory,
    {
      ...DEFAULT_HANDLE_OPTIONS,
      Tags: [
        { name: 'Module', value: DEFAULT_MODULE_ID },
        { name: 'Action', value: 'Eval' }
      ],
      Data: contractSource || bundledContractSources[contractName],
      From: OWNER_ADDRESS
    },
    AO_ENV
  )

  memory = evalResult.Memory

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

    // Stitch Error back in for assertion (aos-loader compatibility)
    if (
      (result.Output.data as string || '').startsWith('\x1B[31mError\x1B[90m')
    ) {
      (result as any).Error = result.Output.data
    }

    return result as AoLoader.HandleResponse & { Error?: string }
  }

  return {
    handle,
    originalHandle,
    memory: memory as unknown as ArrayBuffer
  }
}
