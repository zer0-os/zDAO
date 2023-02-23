import { HardhatUserConfig } from "hardhat/config";

import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan";
import "@openzeppelin/hardhat-upgrades";

// TS Support
import "@typechain/hardhat";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-waffle";

import "hardhat-contract-sizer";

import * as dotenv from "dotenv";
dotenv.config({path:__dirname+'/.env'});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

declare global {
  namespace NodeJS {
    interface ProcessEnv {
      MAINNET_PRIVATE_KEY: string;
      TESTNET_PRIVATE_KEY: string;
      GOERLI_API_KEY: string;
      RINKEBY_API_KEY: string;
      MAINNET_API_KEY: string;
      ETHERSCAN_API_KEY: string;
    }
  }
}

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.9",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
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
  networks: {
    goerli: {
      url: `https://eth-goerli.alchemyapi.io/v2/${process.env.GOERLI_API_KEY}`,
      accounts: [process.env.TESTNET_PRIVATE_KEY],
    },
    rinkeby: {
      url: `https://eth-rinkeby.alchemyapi.io/v2/${process.env.RINKEBY_API_KEY}`,
      accounts: [process.env.TESTNET_PRIVATE_KEY!],
    },
    mainnet: {
      url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.MAINNET_PRIVATE_KEY}`,
      accounts: [process.env.MAINNET_PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
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
};

export default config;
