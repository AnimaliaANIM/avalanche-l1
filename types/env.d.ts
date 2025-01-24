export { }
declare global {
  namespace NodeJS {
    interface ProcessEnv {
      APP_SECRET: string
      MNEMONIC: string
    }
  }
}
