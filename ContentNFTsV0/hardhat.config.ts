import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";
import "@nomiclabs/hardhat-etherscan";
import "hardhat-abi-exporter";
import "hardhat-deploy";
import "hardhat-deploy-ethers";
import "hardhat-gas-reporter";
import "hardhat-watcher";
import "solidity-coverage";

import { resolve } from "path";
import { config as dotenvConfig } from "dotenv";
import { HardhatUserConfig } from "hardhat/config";
import { removeConsoleLog } from "hardhat-preprocessor";

dotenvConfig({ path: resolve(__dirname, "./.env") });

const MNEMONIC_DEFAULT = "test test test test test test test test test test test junk";
const MNEMONIC_LOCALHOST = process.env.MNEMONIC_LOCALHOST || MNEMONIC_DEFAULT;
const MNEMONIC_TESTNET = process.env.MNEMONIC_TESTNET || MNEMONIC_DEFAULT;

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      chainId: 31337,
      forking: {
        enabled: process.env.FORKING_ENABLED === "true",
        blockNumber: Number(process.env.FORKING_BLOCK_NUM) || undefined,
        url: `https://speedy-nodes-nyc.moralis.io/${process.env.MORALIS_API_KEY}/eth/mainnet/archive`,
      },
      accounts: {
        mnemonic: MNEMONIC_LOCALHOST,
      },
    },
    localhost: {
      chainId: 31337,
      accounts: {
        mnemonic: MNEMONIC_LOCALHOST,
      },
    },
    rinkeby: {
      chainId: 4,
      url: `https://speedy-nodes-nyc.moralis.io/${process.env.MORALIS_API_KEY}/eth/rinkeby`,
      accounts: {
        mnemonic: MNEMONIC_TESTNET,
      },
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.9",
        settings: {
          optimizer: {
            enabled: true,
            runs: 800,
          },
        },
      },
    ],
    settings: {
      outputSelection: {
        "*": {
          "*": ["storageLayout"],
        },
      },
    },
  },
  abiExporter: {
    path: "./abi",
    clear: false,
    flat: true,
  },
  typechain: {
    outDir: "types",
    target: "ethers-v5",
  },
  paths: {
    artifacts: "./artifacts",
    cache: "./cache",
    sources: "./contracts",
    tests: "./test",
  },
  preprocess: {
    eachLine: removeConsoleLog(
      (bre) => bre.network.name !== "hardhat" && bre.network.name !== "localhost",
    ),
  },
  watcher: {
    compile: {
      tasks: ["compile"],
      files: ["./contracts"],
      verbose: true,
    },
  },
  mocha: {
    timeout: 20000,
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  gasReporter: {
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    currency: "USD",
    enabled: process.env.REPORT_GAS_ENABLED === "true" ? true : false,
    excludeContracts: [],
    src: "./contracts",
  },
};

export default config;
