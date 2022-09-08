
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
    // const StrategyRouterLib =await ethers.getContractFactory("StrategyRouterLib");
    // const strategyRouterLib = await StrategyRouterLib.deploy();
    // strategyRouterLib.deployed();
    // const libAddress = strategyRouterLib.address;

    // const StrategyRouter =await ethers.getContractFactory(
    //   "StrategyRouter",
    //   {
    //     libraries: {
    //       StrategyRouterLib: libAddress,
    //     },
    //   }
    // );
    const DodoStrategy =await ethers.getContractFactory("DodoStrategyOnefile");
    const StargateStrategy =await ethers.getContractFactory("StargateStrategyOnefile");

    // let artifact;
    // if(contractArtifact === "CBridgeUSDT") {
    //   const {
    //     strategyRouter,
    //     poolId,
    //     tokenA,
    //     tokenB,
    //     celrRewardToken,
    //     farm,
    //     celrRouter,
    //     cBridgeRouter
    //   } = params;
    //   artifact = await Artifact?.deploy( strategyRouter, poolId, tokenA, tokenB, celrRewardToken, farm, celrRouter, cBridgeRouter);
    // }

    // if(contractArtifact === "DodoStrategy") {
    //   const {
    //     strategyRouter,
    //     poolId,
    //     tokenA,
    //     tokenB,
    //     lpToken
    //   } = params;
    //   artifact = await Artifact?.deploy( strategyRouter, poolId, tokenA, tokenB, lpToken);
    // }

    // if(contractArtifact === "StargateStrategy") {
    //   const {
    //     strategyRouter,
    //     poolId,
    //     tokenA,
    //     lpToken,
    //     stgRewardToken,
    //     farm,
    //     stgRouter,
    //     stargateRouter
    //   } = params;
    //   artifact = await Artifact?.deploy( strategyRouter, poolId, tokenA, lpToken, stgRewardToken, farm, stgRouter, stargateRouter );
    // }
    // if(contractArtifact === "StrategyRouter") {
    //   artifact = await Artifact?.deploy();
    // }
   
    // const strategyRouter = await StrategyRouter.deploy();
    const dodoStrategy = await DodoStrategy.deploy();
    const stargateStrategy = await StargateStrategy.deploy();

    // await strategyRouter.deployed();
    await dodoStrategy.deployed();
    await stargateStrategy.deployed();

    // const address = strategyRouter.address;
    const address2 = dodoStrategy.address;
    const address3 = stargateStrategy.address;

    // console.log("strategyRouter : deployed to", address ); 
    console.log("dodoStrategy : deployed to", address2 ); 
    console.log("StargateStrategy : deployed to", address3 ); 
  // deploy("StrategyRouter")
  // deploy("DodoStrategy");
  // deploy("StargateStrategy");
  
}
  
  // We recommend this pattern to be able to use async/await everywhere
  // and properly handle errors.
  main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
  
