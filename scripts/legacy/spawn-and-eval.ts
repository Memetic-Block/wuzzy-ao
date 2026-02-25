#!/usr/bin/env node

/**
 * spawn-eval.js
 *
 * Bare-bones script to spawn a HyperBEAM AO process and evaluate Lua code
 * from a file against it. All configuration via environment variables.
 *
 * Environment variables:
 *   WALLET_PATH  (required) — path to Arweave JWK wallet file
 *   EVAL_FILE    (required) — path to .lua file containing code to evaluate
 *   AO_URL       — HyperBEAM node URL        (default: https://push.forward.computer)
 *   GATEWAY_URL  — Arweave gateway URL        (default: https://arweave.net)
 *   MODULE       — AO module TX ID            (default: hyper module from package.json)
 *   SCHEDULER    — scheduler address           (default: n_XZJhUnmldNFo4dhajoPZWhBXuJk-OcQr5JQ49c4Zo)
 *   AUTHORITY    — node authority address      (auto-resolved from AO_URL if not set)
 *   PROCESS_NAME — Name tag for the process   (default: 'default')
 *
 * Usage:
 *   WALLET_PATH=~/.aos.json EVAL_FILE=test.lua node scripts/spawn-eval.js
 */

import { readFileSync } from 'fs'
import { resolve } from 'path'
import { connect, createSigner } from '@permaweb/aoconnect'
import Arweave from 'arweave'

// ---------------------------------------------------------------------------
// Config from env
// ---------------------------------------------------------------------------

const WALLET_PATH = process.env.WALLET_PATH || 'wallet.json'
const EVAL_FILE = process.env.EVAL_FILE || 'test.lua'
const AO_URL = process.env.AO_URL || 'https://push.forward.computer'
const GATEWAY_URL = process.env.GATEWAY_URL || 'https://arweave.net'
const MODULE = process.env.MODULE || 'wal-fUK-YnB9Kp5mN8dgMsSqPSqiGx-0SvwFUSwpDBI'
const SCHEDULER = process.env.SCHEDULER || 'n_XZJhUnmldNFo4dhajoPZWhBXuJk-OcQr5JQ49c4Zo'
const PROCESS_NAME = process.env.PROCESS_NAME || 'default'

// ---------------------------------------------------------------------------
// Validate required env vars
// ---------------------------------------------------------------------------

if (!WALLET_PATH) {
  console.error('Error: WALLET_PATH env var is required (path to Arweave JWK file)')
  process.exit(1)
}
if (!EVAL_FILE) {
  console.error('Error: EVAL_FILE env var is required (path to .lua file to evaluate)')
  process.exit(1)
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function loadWallet () {
  try {
    return JSON.parse(readFileSync(resolve(WALLET_PATH), 'utf-8'))
  } catch (err) {
    console.error(`Error: Could not read wallet from ${WALLET_PATH}: ${err.message}`)
    process.exit(1)
  }
}

function loadLuaSource () {
  try {
    return readFileSync(resolve(EVAL_FILE), 'utf-8')
  } catch (err) {
    console.error(`Error: Could not read Lua file from ${EVAL_FILE}: ${err.message}`)
    process.exit(1)
  }
}

async function resolveAuthority () {
  if (process.env.AUTHORITY) return process.env.AUTHORITY
  const res = await fetch(`${AO_URL}/~meta@1.0/info/address`)
  if (!res.ok) throw new Error(`Failed to resolve authority from ${AO_URL}: ${res.status}`)
  return res.text()
}

type EvalResult = {
  Output: any;
  Messages: any;
  Assignments: any;
  Spawns: any;
  Error: any;
}

function formatOutput (result: EvalResult) {
  if (result?.Error) return `Error: ${typeof result.Error === 'string' ? result.Error : JSON.stringify(result.Error)}`
  if (result?.Output?.data) {
    const d = result.Output.data
    return typeof d === 'string' ? d : (d.output ?? d.json ?? JSON.stringify(d))
  }
  return JSON.stringify(result, null, 2)
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main () {
  const wallet = loadWallet()
  const luaSource = loadLuaSource()
  const arweave = Arweave.init({})
  const address = await arweave.wallets.getAddress(wallet)
  const authority = await resolveAuthority()

  console.log(`Wallet:    ${address}`)
  console.log(`AO Node:   ${AO_URL}`)
  console.log(`Module:    ${MODULE}`)
  console.log(`Scheduler: ${SCHEDULER}`)
  console.log(`Authority: ${authority}`)
  console.log(`Name:      ${PROCESS_NAME}`)
  console.log()

  // -- Setup aoconnect --
  const ao = connect({
    MODE: 'mainnet',
    signer: createSigner(wallet),
    GATEWAY_URL,
    URL: AO_URL,
    SCHEDULER
  })

  // -- Spawn --
  console.log('Spawning process...')
  const processId = await ao.spawn({
    tags: [
      { name: 'App-Name', value: 'aos' },
      { name: 'Name', value: PROCESS_NAME },
      { name: 'aos-version', value: '2.0.11' },
      { name: 'process-timestamp', value: Date.now().toString() }
    ],
    authority,
    module: MODULE,
    data: ''
  })
  console.log(`Process spawned: ${processId}`)
  console.log()

  // -- Eval --
  console.log(`Evaluating ${EVAL_FILE} ...`)
  const slot = await ao.message({
    process: processId,
    tags: [
      { name: 'Action', value: 'Eval' },
      { name: 'message-timestamp', value: Date.now().toString() }
    ],
    data: luaSource
  })

  const evalResult = await ao.result({
    slot,
    process: processId
  })

  console.log()
  console.log('--- Result ---')
  console.log(formatOutput(evalResult))
}

main().catch(err => {
  console.error('Fatal:', err)
  process.exit(1)
})
