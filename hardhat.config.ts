import 'dotenv/config'
import { HardhatUserConfig } from 'hardhat/config'
import '@nomicfoundation/hardhat-toolbox'

const config: HardhatUserConfig = {
  solidity: {
    compilers: [{
      version: '0.8.28',
    }],
    overrides: {
      'contracts/AnimaliaTitans.sol': {
        version: '0.8.24',
        settings: {
          optimizer: {
            enabled: false,
            runs: 200,
          },
          evmVersion: 'paris',
        },
      },
    },
  },
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {
      blockGasLimit: 30_000_000,
      throwOnCallFailures: true,
      allowUnlimitedContractSize: true,
      accounts: {
        mnemonic: process.env.MNEMONIC,
        accountsBalance: '1000000000000000000000000',
      },
    },
    sepolia: {
      url: 'https://rpc.sepolia.org',
      chainId: 11155111,
      accounts: {
        mnemonic: process.env.MNEMONIC,
      },
    },
    mainnet: {
      url: 'https://eth.llamarpc.com',
      chainId: 1,
      accounts: {
        mnemonic: process.env.MNEMONIC,
      },
    },
    'avalanche-fuji': {
      url: 'https://api.avax-test.network/ext/bc/C/rpc',
      chainId: 43113,
      accounts: {
        mnemonic: process.env.MNEMONIC,
      },
    },
    avalanche: {
      url: 'https://api.avax.network/ext/bc/C/rpc',
      chainId: 43114,
      accounts: {
        mnemonic: process.env.MNEMONIC,
      },
    },
  },
}

export default config
