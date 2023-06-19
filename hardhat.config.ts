import 'hardhat-typechain'
import '@nomiclabs/hardhat-ethers'
import '@nomiclabs/hardhat-waffle'
import '@nomiclabs/hardhat-etherscan'

export default {
  networks: {
    hardhat: {
      allowUnlimitedContractSize: false,
    },
    goerli: {
      url: `https://goerli.infura.io/v3/d0f84142d2e94a9e9f66d397********`,
      accounts: ["********09db1a989c12fb6348c4************************************"]
    },
    arbitrum: {
      url: `https://arbitrum-goerli.infura.io/v3/d0f84142d2e94a9e9f66d397********`,
      accounts: ["********09db1a989c12fb6348c4************************************"]
    },
    optimism: {
      url: `https://optimism-goerli.infura.io/v3/d0f84142d2e94a9e9f66d397********`,
      accounts: ["********09db1a989c12fb6348c4************************************"]
    },
    mumbai: {
      url: `https://polygon-mumbai.infura.io/v3/d0f84142d2e94a9e9f66d397********`,
      accounts: ["********09db1a989c12fb6348c4************************************"]
    }
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: '********J3T6BMZT3JCPS9SVZ8C*******',
  },
  solidity: {
    version: '0.6.6',
    settings: {
      optimizer: {
        enabled: true,
        runs: 600,
      },
      metadata: {
        // do not include the metadata hash, since this is machine dependent
        // and we want all generated code to be deterministic
        // https://docs.soliditylang.org/en/v0.7.6/metadata.html
        // bytecodeHash: 'none',
      },
    },
  },
}
