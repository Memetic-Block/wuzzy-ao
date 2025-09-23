import 'dotenv/config'
import { readFileSync } from 'fs'
import { connect, createSigner } from '@permaweb/aoconnect'
import Arweave from 'arweave'

// import { logger } from './util/logger'
const logger = console

const HYPERBEAM_URL = process.env.HYPERBEAM_URL || 'https://forward.computer'
const PRIVATE_KEY = process.env.PRIVATE_KEY || ''
if (!PRIVATE_KEY) {
  throw new Error('PRIVATE_KEY is not set!')
}
const wallet = JSON.parse(readFileSync(PRIVATE_KEY, 'utf-8'))

const MODULE = process.env.MODULE
  || 'xVcnPK8MPmcocS6zwq1eLmM2KhfyarP8zzmz3UVi1g4'
const NAME = process.env.PROCESS_NAME
const GATEWAY = process.env.GATEWAY || 'https://arweave.net'
const PROCESS_ID = process.env.PROCESS_ID || ''
if (!PROCESS_ID) {
  throw new Error('PROCESS_ID is not set!')
}

async function doEval() {
  const address = await Arweave.init({}).wallets.getAddress(wallet)
  logger.info(`Spawning new hyper-aos process [${NAME || 'unnamed'}]`)
  logger.info(`Wallet = [${address}]`)
  logger.info(`Module = [${MODULE}]`)
  logger.info(`Gateway = [${GATEWAY}]`)
  logger.info(`Hyperbeam = [${HYPERBEAM_URL}]`)

  const { request } = connect({
    MODE: 'mainnet',
    device: 'process@1.0',
    signer: createSigner(wallet),
    GATEWAY_URL: GATEWAY,
    URL: HYPERBEAM_URL
  })



  async function tryEval(maxAttempts = 3, delayMs = 5000) {
    // Build eval parameters like AOS CLI sendMessageMainnet does
    const evalParams = {
      type: 'Message',
      path: `/${PROCESS_ID}/push`, // AOS CLI path format
      method: 'POST',
      action: 'Eval',
      'data-protocol': 'ao',
      target: PROCESS_ID,
      'signing-format': 'ANS-104',
      data: 'HELLO = \'WORLD1\''
      // data: "require('.process')._version"
    }
    logger.info('Eval parameters:', JSON.stringify(evalParams, null, 2))
    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        logger.info(`Eval attempt ${attempt}/${maxAttempts}`)
        const evalResult = await request(evalParams)
        
        logger.info(`Raw eval result:`, evalResult)
        
        // Handle results like AOS CLI does - check if it's already parsed
        let parsedResult
        if (evalResult && typeof evalResult === 'object') {
          // If it's already an object, check for AOS-specific properties
          if (evalResult.body && typeof evalResult.body === 'string') {
            try {
              const body = JSON.parse(evalResult.body)
              parsedResult = body
            } catch (e) {
              parsedResult = { body: evalResult.body }
            }
          } else {
            parsedResult = evalResult
          }
        } else {
          parsedResult = evalResult
        }
        
        logger.info(`Parsed eval result: [${JSON.stringify(parsedResult, null, 2)}]`)
        return parsedResult
      } catch (error: any) {
        logger.error(`Eval attempt ${attempt} failed:`)
        
        // Log the error details to understand what's happening
        logger.error('Full error object:', error)
        
        if (error.response) {
          logger.error(`Status: ${error.response.status}`)
          logger.error(`Status Text: ${error.response.statusText}`)
          logger.error(`Response Data:`, error.response.data)
        } else if (error.message) {
          logger.error(`Error Message: ${error.message}`)
        }
        
        // Check if this is actually a successful response disguised as an error
        if (error.message && (error.message.includes('print: true') || error.message.includes('prompt:'))) {
          logger.info('✅ Detected successful execution! The "error" contains successful AOS output.')
          logger.info('AOS Response Data:')
          
          // Parse the multipart response to extract useful info
          const lines = error.message.split('\n')
          for (const line of lines) {
            if (line.includes('data:')) {
              logger.info(`  ${line}`)
            }
            if (line.includes('print:')) {
              logger.info(`  ${line}`)
            }
            if (line.includes('prompt:')) {
              logger.info(`  ${line}`)
            }
          }
          
          return { 
            success: true, 
            output: 'Eval executed successfully',
            details: 'Process is responsive and ready for commands',
            rawResponse: error.message
          }
        }
        
        if (attempt < maxAttempts) {
          logger.info(`Waiting ${delayMs}ms before retry...`)
          await new Promise(resolve => setTimeout(resolve, delayMs))
        } else {
          throw new Error(`Eval failed after ${maxAttempts} attempts: ${error.message || error}`)
        }
      }
    }
  }

  await tryEval(1)

  const currentSlotPath = `/${PROCESS_ID}/slot/current/body` // LIVE PARAMS
  const currentSlotParams = {
    path: currentSlotPath,
    method: 'GET'
  }
  const currentSlot = await request(currentSlotParams)
  console.log('currentSlot result', JSON.stringify(currentSlot, null, 2))
}

doEval().then(() => {
  logger.info('✅ EVAL AO Process executed successfully!')
}).catch(error => {
  // Check if this is actually a successful response disguised as an error
  if (error.message && (error.message.includes('print: true') || error.message.includes('prompt:'))) {
    console.log('error.message', error.message)
    process.exit(0)
  } else {
    logger.error(`❌ Error executing spawn AO Process:`, error)
    process.exit(1)
  }
})
