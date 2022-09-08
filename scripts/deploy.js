
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
  const deploy = async(contractArtifact, params) => {
    const [deployer] = await hre.ethers.getSigners();
    console.log(`Deploying ${contractArtifact} with the account:`, deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());
    const Artifact =await ethers.getContractFactory(contractArtifact);
    let artifact;
    if(contractArtifact === "CBridgeUSDT") {
      const {
        strategyRouter,
        poolId,
        tokenA,
        tokenB,
        celrRewardToken,
        farm,
        celrRouter,
        cBridgeRouter
      } = params;
      artifact = await Artifact?.deploy( strategyRouter, poolId, tokenA, tokenB, celrRewardToken, farm, celrRouter, cBridgeRouter);
    }

    if(contractArtifact === "DodoStrategy") {
      const {
        strategyRouter,
        poolId,
        tokenA,
        tokenB,
        lpToken
      } = params;
      artifact = await Artifact?.deploy( strategyRouter, poolId, tokenA, tokenB, lpToken);
    }

    if(contractArtifact === "StargateStrategy") {
      const {
        strategyRouter,
        poolId,
        tokenA,
        tokenB,
        stgRewardToken,
        farm,
        stgRouter,
        stargateRouter
      } = params;
      artifact = await Artifact?.deploy( strategyRouter, poolId, tokenA, tokenB, stgRewardToken, farm, stgRouter, stargateRouter );
    }

    await artifact.deployed();
    const address = artifact?.address;
    console.log(`${contractArtifact} : deployed to ${address}` ); 
  }

  deploy(
    "CBridgeUSDT",
    {
      strategyRouter: "supplyParameterHere",
      poolId: "supplyParameterHere",
      tokenA: "supplyParameterHere",
      tokenB: "supplyParameterHere",
      celrRewardToken: "supplyParameterHere",
      farm: "supplyParameterHere",
      celrRouter: "supplyParameterHere",
      cBridgeRouter: "supplyParameterHere"
    }
  );
  deploy(
    "DodoStrategy",
    {
      strategyRouter: "supplyParamhere",
      poolId: "supplyParamhere",
      tokenA: "supplyParamhere",
      tokenB: "supplyParamhere",
      lpToken: "supplyParamhere",
    }
  );
  deploy(
    "StargateStrategy",
    {
      strategyRouter: "supplyParamterHere",
      poolId: "supplyParamterHere",
      tokenA: "supplyParamterHere",
      tokenB: "supplyParamterHere",
      stgRewardToken: "supplyParamterHere",
      farm: "supplyParamterHere",
      stgRouter: "supplyParamterHere",
      stargateRouter: "supplyParamterHere",
    }
  );
  
}
  
  // We recommend this pattern to be able to use async/await everywhere
  // and properly handle errors.
  main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
  
