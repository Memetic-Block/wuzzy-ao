import fs from 'fs'
import path from 'path'
import AoLoader from '@permaweb/ao-loader'

async function testboot() {
  const PROCESS_ID = ''.padEnd(43, '2')
  const OWNER_ADDRESS = ''.padEnd(42, '1')
  const MODULE_ID = ''.padEnd(43, '3')
  const AOS_WASM = fs.readFileSync(
    path.join(
      path.resolve(),
      // './test/util/aos-cbn0KKrBZH7hdNkNokuXLtGryrWM--PjSTBqIzw9Kkk.wasm'
      // './test/util/aos-Pq2Zftrqut0hdisH_MC2pDOT6S4eQFoxGsFUzR6r350.wasm'
      './test/util/aos64.wasm'
      // './test/util/QEgxNlbNwBi10VXu5DbP6XHoRDHcynP_Qbq3lpNC97s.wasm'
      // './test/util/nEjlSFA_8narJlVHApbczDPkMc9znSqYtqtf1iOdoxM.wasm',
      // './test/util/ISShJH1ij-hPPt9St5UFFr_8Ys3Kj5cyg7zrMGt7H9s.wasm'
    )
  )
  const AOS_FORMAT = 'wasm64-unknown-emscripten-draft_2024_02_15'
  // const AOS_FORMAT = 'wasm32-unknown-emscripten-metering'
  const AO_ENV = {
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

  const handle = await AoLoader(AOS_WASM, {
    format: AOS_FORMAT,
    memoryLimit: '524288000', // in bytes
    computeLimit: 9e12,
    extensions: []
  })

  const result = await handle(null, {
    Id: 'test',
    'Block-Height': '1',
    Timestamp: Date.now(),
    From: OWNER_ADDRESS,
    Owner: OWNER_ADDRESS,
    Target: PROCESS_ID,
    Tags: [
      { name: 'Action', value: 'Eval' }
    ],
    Data: 'print("Hello, World!")',
    Reference: '1',
    Module: MODULE_ID
  }, AO_ENV)

  console.log(`Handle Result `, JSON.stringify({
    Assignments: result.Assignments,
    Messages: result.Messages,
    Output: result.Output,
    Patches: result.Patches,
    Spawns: result.Spawns
  }, null, 2))
}

testboot().then(() => {
  console.log('Test boot completed successfully.')
}).catch(err => {
  console.error('Error during test boot:', err)
  process.exit(1)
})
