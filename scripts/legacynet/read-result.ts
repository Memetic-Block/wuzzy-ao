import 'dotenv/config'
import { aoResult, aoResults, aoGetMessages } from '../util/send-aos-message'

const processId = process.env.PROCESS_ID || ''
const messageId = process.env.MESSAGE_ID || ''
if (!processId) {
  throw new Error('PROCESS_ID is not set!')
}

async function readResult() {
  if (messageId) {
    const result = await aoResult({
      message: messageId,
      process: processId
    })
    console.log(`Got AO Message result ${messageId} from process ${processId}`)
    console.dir(result, { depth: null })
  } else {
    const results = await aoResults({ process: processId })
    console.log(
      `Got ${results.edges.length} AO Message results from process ${processId}`
    )
    results.edges.forEach((edge, index) => {
      console.log(`--- Result ${index + 1} ---`)
      console.dir(edge.node, { depth: null })
    })
  }
}

readResult().catch(e => {
  console.error(e)
  process.exit(1)
})
