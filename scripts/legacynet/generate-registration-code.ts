import 'dotenv/config'
import { createHash, randomBytes } from 'node:crypto'

const secretLength = parseInt(process.env.SECRET_LENGTH || '32', 10)

/**
 * Generate a registration code for the Wuzzy Nest Registry.
 *
 * Creates a random secret and its SHA2-512 hash. The secret is the
 * registration code given to the nest operator. The hash is stored
 * in the registry via Add-Registration-Code.
 *
 * Env vars:
 *  - SECRET_LENGTH: byte length of the random secret (default 32)
 */
async function generateRegistrationCode() {
  const secret = randomBytes(secretLength)
  const secretHex = secret.toString('hex')

  const hash = createHash('sha512').update(secretHex).digest('hex')

  console.log('')
  console.log(`Registration Code (give to nest operator):`)
  console.log(`  ${secretHex}`)
  console.log('')
  console.log(`Hash (store via Add-Registration-Code):`)
  console.log(`  ${hash}`)
}

generateRegistrationCode()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error('Failed to generate registration code:', e)
    process.exit(1)
  })
