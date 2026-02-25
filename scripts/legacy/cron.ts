import 'dotenv/config'
import { ChildProcessWithoutNullStreams, spawn } from 'node:child_process'
import { logger } from '../util/logger'

const HYPERBEAM_ENDPOINT = process.env.HYPERBEAM_ENDPOINT || ''
if (!HYPERBEAM_ENDPOINT) {
  throw new Error('HYPERBEAM_ENDPOINT is not set!')
}
const PROCESS_ID = process.env.PROCESS_ID || ''
if (!PROCESS_ID) {
  throw new Error('PROCESS_ID is not set!')
}
const PRIVATE_KEY = process.env.PRIVATE_KEY || ''
if (!PRIVATE_KEY) {
  throw new Error('PRIVATE_KEY is not set!')
}

let aos: ChildProcessWithoutNullStreams | null = null
export async function cron() {
  logger.info(`Sending Cron to process id ${PROCESS_ID}`)

  aos = spawn('aos', [PROCESS_ID, '--url', HYPERBEAM_ENDPOINT, '--wallet', PRIVATE_KEY])

  let output = ''
  let cronSent = false
  aos.stdout.on('data', async data => {
    const dataString = data.toString()
    output += dataString
    console.log('o', dataString)

    if (dataString.includes('hyper') && dataString.includes('aos') && !cronSent) {
      cronSent = true
      aos!.stdin.write('send({ target = id, action = "Cron" })\n', async () => {
        aos!.stdin.end()
        await new Promise(r => setTimeout(r, 10_000))
        aos!.kill()
      })
    }
  })
}

cron()
  .then(() => { logger.info('Cron executed successfully!') })
  .catch(error => {
    logger.error(`Error executing cron: ${error.message}`, error.stack)
    process.exit(1)
  })
