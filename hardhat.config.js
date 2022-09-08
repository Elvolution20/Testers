// const { parseEther } = require("ethers/lib/utils");
// const { extendEnvironment } = require("hardhat/config");

// require("dotenv").config();
// require("@nomiclabs/hardhat-waffle");
// require("hardhat-gas-reporter");
// require("@nomiclabs/hardhat-etherscan");
// require('hardhat-contract-sizer');
// require('@openzeppelin/hardhat-upgrades');
// require('solidity-docgen');

// const networkVariables = require('./networkVariables');

// // Fill networkVariables object with settings and addresses based on current network or fork.
// extendEnvironment((hre) => {
//   if(hre.network.name == 'hardhat') {
//     if(hre.network.config.forking.enabled) {
//       switch (hre.network.config.forking.url) {
//         case process.env.BNB_URL:
//           // console.log(networkVariables);
//           hre.networkVariables = networkVariables['bnb'];
//           break;
//         case process.env.BNB_TEST_URL:
//           // console.log(networkVariables);
//           hre.networkVariables = networkVariables['bnbTest'];
//           break;
//       }
//     }
//   } else {
//     hre.networkVariables = networkVariables[hre.network.name];
//   }
//   if(!hre.networkVariables) throw Error("network variables are missing");
//   // console.log(hre.networkVariables);
// });

// /**
//  * @type import('hardhat/config').HardhatUserConfig
//  */
// module.exports = {
//   networks: {
//     hardhat: {
//       forking: {
//         url: process.env.BNB_URL,
//         // blockNumber: 19232650, // use this only with archival node
//         enabled: true
//       },
//       // allowUnlimitedContractSize: true,
//       // loggingEnabled: false
//       // accounts: [{privateKey: process.env.PRIVATE_KEY, balance: parseEther("10000").toString()}],
//     },
//     bnb: {
//       url: `${process.env.BNB_URL}`,
//       accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
//       gas: 20e6 // lets see if this solves problem, as auto gas estimation makes deploy scripts to fail
//     },
//     bnbTest: {
//       url: process.env.BNB_TEST_URL ?? '',
//       accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
//       gas: 20e6 // lets see if this solves problem, as auto gas estimation makes deploy scripts to fail
//     },
//   },
//   gasReporter: {
//     enabled: process.env.REPORT_GAS !== undefined,
//   },
//   mocha: {
//     bail: true,
//     timeout: 6000000
//   },
//   etherscan: {
//     apiKey: {
//       bsc: process.env.BSCSCAN_API_KEY
//     }
//   },
//   docgen: {
//     pages: "files"
//   },
//   solidity: {
//     compilers: [
//       {
//         version: "0.8.4",
//         settings: {
//           optimizer: {
//             enabled: true,
//             runs: 200,
//           },
//           evmVersion: "istanbul",
//           outputSelection: {
//             "*": {
//               "": ["ast"],
//               "*": [
//                 "evm.bytecode.object",
//                 "evm.deployedBytecode.object",
//                 "abi",
//                 "evm.bytecode.sourceMap",
//                 "evm.deployedBytecode.sourceMap",
//                 "metadata",
//               ],
//             },
//           },
//         },
//       },
//       {
//         version: "0.6.6",
//         settings: {
//           optimizer: {
//             enabled: true,
//             runs: 200,
//           },
//           evmVersion: "istanbul",
//           outputSelection: {
//             "*": {
//               "": ["ast"],
//               "*": [
//                 "evm.bytecode.object",
//                 "evm.deployedBytecode.object",
//                 "abi",
//                 "evm.bytecode.sourceMap",
//                 "evm.deployedBytecode.sourceMap",
//                 "metadata",
//               ],
//             },
//           },
//         },
//       },
//     ]
//   },
// };





// import { config } from "dotenv";
// import type { HardhatUserConfig } from "hardhat/types";
// import "@nomiclabs/hardhat-ethers";
// import "@openzeppelin/hardhat-upgrades";
// import "@nomiclabs/hardhat-waffle";
// import "@nomiclabs/hardhat-truffle5";
// import "@nomiclabs/hardhat-web3";
// import "solidity-coverage";

require("dotenv").config();
require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");
require("@nomiclabs/hardhat-etherscan");
require('hardhat-contract-sizer');
require('@openzeppelin/hardhat-upgrades');
require('solidity-docgen');
// var HDWalletProvider = require("truffle-hdwallet-provider");


// config();

// const confg: HardhatUserConfig = {
//   solidity: "0.8.4"
// }
// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  // defaultNetwork: "matic",
  networks: {
    // hardhat: {
    //   initialBaseFeePerGas: 0, // workaround from https://github.com/sc-forks/solidity-coverage/issues/652#issuecomment-896330136 . Remove when that issue is closed.
    // },
    hardhat: {
    },
    development: {
      url: "http://127.0.0.1:8545",     // Localhost (default: none)
      port: 8545,            // Standard Ethereum port (default: none)
      network_id: "*",       // Any network (default: none)
    },

    ropsten: {
      url: process.env.ROPSTEN_URL || "",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },

    // rinkeby: {
    //   url: process.env.RINKEBY_URL || "",
    //   accounts:
    //     process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    // },

    testnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      gasPrice: 20000000000,
      accounts: {mnemonic: process.env.MNEMONIC}
    },

    mainnet: {
      url: "https://bsc-dataseed.binance.org/",
      chainId: 56,
      gasPrice: 20000000000,
      accounts: {mnemonic: process.env.MNEMONIC}
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },

  paths: {
    sources: "./contracts",
    tests: "./test",
    scripts: "./scripts",
    cache: "./cache",
    artifacts: "./artifacts"
  },

  mocha: {
    timeout: 200000
  },

  solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  }
}
