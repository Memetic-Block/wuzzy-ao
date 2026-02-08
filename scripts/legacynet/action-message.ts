import 'dotenv/config'
import { readFileSync } from 'fs'
import { createDataItemSigner } from '@permaweb/aoconnect'
import { sendAosDryRun, sendAosMessage } from '../util/send-aos-message'

const processId = process.env.PROCESS_ID || ''
const action = process.env.ACTION || ''
const data = process.env.DATA || undefined
const tagsInput = process.env.TAGS || ''
const dryRun = process.env.DRY_RUN !== 'false' // defaults to true for safety
const walletPath = process.env.DEPLOYER_PRIVATE_KEY_PATH || ''

if (!processId) {
  throw new Error('PROCESS_ID is not set!')
}

if (!action) {
  throw new Error('ACTION is not set!')
}

if (!dryRun && !walletPath) {
  throw new Error('DEPLOYER_PRIVATE_KEY_PATH is required when DRY_RUN=false!')
}

// Parse additional tags from TAGS env var (JSON array of {name, value} objects)
let additionalTags: { name: string; value: string }[] = []
if (tagsInput) {
  try {
    additionalTags = JSON.parse(tagsInput)
    if (!Array.isArray(additionalTags)) {
      throw new Error('TAGS must be a JSON array')
    }
  } catch (e) {
    throw new Error(`Failed to parse TAGS as JSON: ${e.message}`)
  }
}

async function sendActionMessage() {
  const tags = [
    { name: 'Action', value: action },
    ...additionalTags
  ]

  console.info(`Sending Action [${action}] to Process [${processId}]`)
  console.info(`Mode: ${dryRun ? 'DRY_RUN (read-only)' : 'MESSAGE (write)'}`)

  if (additionalTags.length > 0) {
    console.info(`Tags: ${JSON.stringify(additionalTags)}`)
  }

  if (data) {
    console.info(`Data: ${data}`)
  }

  if (dryRun) {
    const result = await sendAosDryRun({ processId, tags, data })

    if (result.result?.Messages && result.result.Messages[0]) {
      console.log('\n--- Response ---')
      console.log(result.result.Messages[0].Data)
    } else {
      console.error('Result error:', JSON.stringify(result.result, null, 2))
    }
  } else {
    const jwk = JSON.parse(readFileSync(walletPath, 'utf-8'))
    const signer = createDataItemSigner(jwk)

    const { messageId, result } = await sendAosMessage({
      processId,
      tags,
      data,
      signer: signer as any
    })

    console.log('\n--- Response ---')
    console.log(`Message ID: ${messageId}`)

    if (result?.Messages && result.Messages[0]) {
      console.log(result.Messages[0].Data)
    } else {
      console.log('Result:', JSON.stringify(result, null, 2))
    }
  }
}

sendActionMessage().catch(e => {
  console.error(e)
  process.exit(1)
})
