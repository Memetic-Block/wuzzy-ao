import 'dotenv/config'
import { sendAosDryRun } from '../util/send-aos-message'

const processId = process.env.PROCESS_ID || ''

if (!processId) {
  throw new Error('PROCESS_ID is not set!')
}

async function dryrunViewState() {
  const result = await sendAosDryRun({
    processId,
    tags: [ { name: 'Action', value: 'View-State' } ]
  })
  if (result.result?.Messages && result.result.Messages[0]) {
    console.dir(JSON.parse(result.result.Messages[0].Data), { depth: null })
  } else {
    console.error('Result error:', JSON.stringify(result.result, null, 2))
  }
}

dryrunViewState().catch(e => {
  console.error(e)
  process.exit(1)
})
