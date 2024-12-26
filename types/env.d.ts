export { }
declare global {
  namespace NodeJS {
    interface ProcessEnv {
      MNEMONIC: string
    }
  }
}
