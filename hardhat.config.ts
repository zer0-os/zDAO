import * as dotenv from "dotenv";

import { HardhatUserConfig } from "hardhat/config";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@openzeppelin/hardhat-upgrades";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "hardhat-contract-sizer";
import "solidity-coverage";
import { removeConsoleLog } from "hardhat-preprocessor";

dotenv.config({path:__dirname+'/.env'});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

declare global {
  namespace NodeJS {
    interface ProcessEnv {
      GOERLI_API_KEY: string;
      RINKEBY_API_KEY: string;
      MAINNET_API_KEY: string;
      MUMBAI_API_KEY: string;
      POLYGON_API_KEY: string;
      ETHERSCAN_API_KEY: string;
      POLYGONSCAN_API_KEY: string;

      TESTNET_PRIVATE_KEY: string;
      MAINNET_PRIVATE_KEY: string;
    }
  }
}

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.11",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          },
          outputSelection: {
            "*": {
              "*": ["storageLayout"],
            },
          },
        },
      },
    ],
  },
  defaultNetwork: 'hardhat',
  networks: {
    goerli: {
      url: `https://eth-goerli.alchemyapi.io/v2/${process.env.GOERLI_API_KEY}`,
      accounts: [process.env.TESTNET_PRIVATE_KEY],
    },
    rinkeby: {
      url: `https://eth-rinkeby.alchemyapi.io/v2/${process.env.RINKEBY_API_KEY}`,
      accounts: [process.env.TESTNET_PRIVATE_KEY],
    },
    mainnet: {
      url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.MAINNET_API_KEY}`,
      accounts: [process.env.MAINNET_PRIVATE_KEY],
    },
    polygonMumbai: {
      url: `https://polygon-mumbai.infura.io/v3/97e75e0bbc6a4419a5dd7fe4a518b917`,
      accounts: [process.env.TESTNET_PRIVATE_KEY],
    },
    polygon: {
      url: `https://polygon-mainnet.g.alchemy.com/v2/${process.env.POLYGON_API_KEY}`,
      accounts: [process.env.MAINNET_PRIVATE_KEY],
    },
    hardhat: {
      throwOnTransactionFailures: true,
      throwOnCallFailures: true,
      initialBaseFeePerGas: 0,
      gasPrice: 0x01,
    },
  },
  etherscan: {
    apiKey: {
      goerli: process.env.ETHERSCAN_API_KEY,
      rinkeby: process.env.ETHERSCAN_API_KEY,
      mainnet: process.env.ETHERSCAN_API_KEY,
      polygonMumbai: process.env.POLYGONSCAN_API_KEY,
      polygon: process.env.POLYGONSCAN_API_KEY,
    },
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
  },
  typechain: {
    outDir: "types",
    target: "ethers-v5",
  },
  preprocess: {
    eachLine: removeConsoleLog(
      (hre) =>
        hre.network.name !== "hardhat" && hre.network.name !== "localhost"
    ),
  },
};

export default config;
