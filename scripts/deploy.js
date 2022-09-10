
// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
// require('@nomiclabs/hardhat-ethers');
// const { ethers, upgrades } = require('hardhat');

// COMMAND : npx hardhat run --network harmony_testnet scripts/deploy.js
const Web3 = require("web3");

async function main() {
  // const deploy = async(contractArtifact) => {
    const [deployer] = await hre.ethers.getSigners();
    console.log(`Deploying with the account:`, deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());
    const StrategyRouterLib =await ethers.getContractFactory("contracts/verify/StrategyRouterOneFile.sol:StrategyRouterLib");
    const strategyRouterLib = await StrategyRouterLib.deploy();
    strategyRouterLib.deployed();
    const libAddress = strategyRouterLib.address;

    const StrategyRouter =await ethers.getContractFactory(
      "StrategyRouterOnefile",
      {
        libraries: {
          StrategyRouterLib: libAddress,
        },
      }
    );
    // StrategyRouter
    const strategyRouter = await StrategyRouter.deploy();
    await strategyRouter.deployed();
    const strategyAddress = strategyRouter.address;
    console.log("strategyAddress : deployed to", strategyAddress ); 
    console.log("libAddress : deployed to", libAddress ); 

    // // SharesToken
    // const ShareToken =await ethers.getContractFactory("SharesTokenOnefile");
    // const shareToken = await ShareToken.deploy(strategyAddress);
    // await shareToken.deployed();
    // const shareTokenAddr = shareToken.address;
    // console.log("shareTokenAddr : deployed to", shareTokenAddr ); 

    // // ChainLinkOracle
    // const ChainlinkOracle =await ethers.getContractFactory("ChainlinkOracleOnefile");
    // const chainlinkOracle = await ChainlinkOracle.deploy();
    // await chainlinkOracle.deployed();
    // const chainlinkAddr = chainlinkOracle.address;
    // console.log("chainlinkAddrgy : deployed to", chainlinkAddr ); 

    // // Batch
    // const Batch = await ethers.getContractFactory("BatchOnefile");
    // const batch = await Batch.deploy();
    // await batch.deployed();
    // const batchAddr = batch.address;
    // console.log("batchAddr : deployed to", batchAddr ); 

    // // Exchange
    // const Exchange =await ethers.getContractFactory("ExchangeOnefile");
    // const exchange = await Exchange.deploy();
    // await exchange.deployed();
    // const exchangeAddr = exchange.address;
    // console.log("exchangeAddr : deployed to", exchangeAddr ); 

    // ReceiptNFT
    const ReceiptNFT =await ethers.getContractFactory("ReceiptNFTOnefile");
    // const strategyAddress = "0x3c096b75636eD910bB25EB587bebFB99BAF8df94";
    const batchAddr = "0x04e5Fbaf98d3Fe94c1c27A68c8eF0Ab46bB0a388"; 
    const receiptNFT = await ReceiptNFT.deploy(strategyAddress, batchAddr);
    await receiptNFT.deployed();
    const receiptNFTAddr = receiptNFT.address;
    console.log("receiptNFTAddr : deployed to", receiptNFTAddr );

    // DodoStrategy
    // const DodoStrategy =await ethers.getContractFactory("DodoStrategyOnefile");
    // const dodoStrategy = await DodoStrategy.deploy();
    // await dodoStrategy.deployed();
    // const dodoAddr = dodoStrategy.address;
    // console.log("dodoAddr : deployed to", dodoAddr ); 


   
    // const strategyRouter = await StrategyRouter.deploy();
    



    // console.log("strategyRouter : deployed to", address ); 
    
    
}
  
  // We recommend this pattern to be able to use async/await everywhere
  // and properly handle errors.
  main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
  
