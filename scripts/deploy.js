
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
    const StrategyRouterLib =await ethers.getContractFactory("contracts/verify/StrategyRouter:StrategyRouterLib");
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
    const strategyRouter = await StrategyRouter.deploy();
    await strategyRouter.deployed();
    const strategyAddress = strategyRouter.address;


    const ShareToken =await ethers.getContractFactory("ShareTokenOnefile");
    const ChainlinkOracle =await ethers.getContractFactory("ChainlinkOracleOnefile");
    const Batch = await ethers.getContractFactory("BatchOnefile");
    const Exchange =await ethers.getContractFactory("ExchangeOnefile");
    const ReceiptNFT =await ethers.getContractFactory("ReceiptNFTOnefile");
    const DodoStrategy =await ethers.getContractFactory("DodoStrategyOnefile");
   
    // const strategyRouter = await StrategyRouter.deploy();
    const dodoStrategy = await DodoStrategy.deploy();
    const shareToken = await ShareToken.deploy(strategyAddress, strategyAddress);
    const chainlinkOracle = await ChainlinkOracle.deploy();
    const batch = await Batch.deploy();
    const exchange = await Exchange.deploy();
    const receiptNFT = await ReceiptNFT.deploy(batchAddress, );
    await receiptNFT.deployed();

    await dodoStrategy.deployed();
    await shareToken.deployed();
    await chainlinkOracle.deployed();
    await batch.deployed();
    await exchange.deployed();

    // const address = strategyRouter.address;
    const dodoAddr = dodoStrategy.address;
    const shareTokenAddr = shareToken.address;
    const chainlinkAddr = chainlinkOracle.address;
    const batchAddr = batch.address;
    const exchangeAddr = exchangey.address;
    const receiptNFTAddr = receiptNFT.address;

    // console.log("strategyRouter : deployed to", address ); 
    console.log("strategyAddress : deployed to", strategyAddress ); 
    console.log("dodoAddr : deployed to", dodoAddr ); 
    console.log("shareTokenAddr : deployed to", shareTokenAddr ); 
    console.log("chainlinkAddrgy : deployed to", chainlinkAddr ); 
    console.log("batchAddr : deployed to", batchAddr ); 
    console.log("exchangeAddr : deployed to", exchangeAddr ); 
    console.log("receiptNFTAddr : deployed to", receiptNFTAddr );
}
  
  // We recommend this pattern to be able to use async/await everywhere
  // and properly handle errors.
  main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
  
