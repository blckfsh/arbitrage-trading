import { HardhatUserConfig } from "hardhat/config";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";

dotenv.config();

const EMPTY_PRIVATE_KEY="0x00000000000000000";

const {
  PRIVATE_KEY,
  ETHERSCAN_API_KEY,
  ALCHEMY_GOERLI_ENDPOINT,  
  ALCHEMY_MAINNET_FORK,
} = process.env;

const config: HardhatUserConfig = {
  solidity: {
    version: "0.7.6",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  mocha: {
    timeout: 60000, // Set the desired timeout value in milliseconds
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY
  },   
  networks: {
    hardhat: {
      forking: {
        url: ALCHEMY_MAINNET_FORK || "",
      },
    },
    goerli: {
      url: `${ALCHEMY_GOERLI_ENDPOINT || ""}`,
      accounts: [`${PRIVATE_KEY || EMPTY_PRIVATE_KEY}`]
    }    
  }
};

export default config;
