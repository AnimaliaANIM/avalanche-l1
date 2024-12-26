require('dotenv').config()

const { createCipheriv, createDecipheriv, randomBytes } = require('crypto')
const { existsSync, readFileSync, writeFileSync } = require('fs')
const { hideBin } = require('yargs/helpers')
const yargs = require('yargs/yargs')

const ALGO = 'aes-256-ctr'
const IV_LENGTH = 16
const KEY_LENGTH = 32
const BUFFER_PADDING = Buffer.alloc(KEY_LENGTH)

yargs(hideBin(process.argv))
  .command('encrypt [input] [output]', 'Encrypt .env file', yargs =>
    yargs
      .option('input', {
        type: 'string',
        default: '.env',
        describe: 'Input file to encrypt',
      })
      .option('output', {
        describe: 'Output file',
        type: 'string',
        default: '.env.encrypted',
      })
      .option('key', {
        describe: 'Encryption key, defaults to process.env.APP_SECRET',
        type: 'string',
      })
    , argv => {
      argv.key = argv.key ?? process.env.APP_SECRET
      if (typeof argv.key !== 'string') {
        throw new Error('Encryption key is required (--key)')
      }

      if (!existsSync(argv.input)) {
        throw new Error(`${argv.input} file does not exist`)
      }

      console.log('Encrypting', argv.input, 'into', argv.output)

      const data = readFileSync(argv.input).toString()
      const ivBuff = randomBytes(IV_LENGTH)
      const cipher = createCipheriv(ALGO, Buffer.concat([Buffer.from(argv.key), BUFFER_PADDING], KEY_LENGTH), ivBuff)
      const encBuff = Buffer.concat([cipher.update(Buffer.from(data)), cipher.final()])

      writeFileSync(argv.output, Buffer.concat([ivBuff, encBuff]).toString('base64'))
    })
  .command('decrypt [input] [output]', 'Decrypt encrypted .env file', yargs =>
    yargs
      .option('input', {
        type: 'string',
        default: '.env.encrypted',
        describe: 'Input file to decrypt',
      })
      .option('output', {
        describe: 'Output file',
        type: 'string',
        default: '.env',
      })
      .option('key', {
        describe: 'Encryption key, defaults to process.env.APP_SECRET',
        type: 'string',
      })
    , argv => {
      argv.key = argv.key ?? process.env.APP_SECRET
      if (typeof argv.key !== 'string') {
        throw new Error('Encryption key is required (--key)')
      }

      if (!existsSync(argv.input)) {
        throw new Error(`${argv.input} file does not exist`)
      }

      const encrypted = readFileSync(argv.input).toString()

      const allData = Buffer.from(encrypted, 'base64')
      const ivBuff = allData.subarray(0, IV_LENGTH)
      const encBuff = allData.subarray(IV_LENGTH)
      const decipher = createDecipheriv(ALGO, Buffer.concat([Buffer.from(argv.key), BUFFER_PADDING], KEY_LENGTH), ivBuff)
      const decBuff = Buffer.concat([decipher.update(encBuff), decipher.final()])

      writeFileSync(argv.output, decBuff.toString('utf8'))
    })
  .version('env.js version 1.0.0')
  .demandCommand(1)
  .help()
  .parse()
