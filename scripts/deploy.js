
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
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // console.log(
  //   "Deploying TestToken: "
  // );
  // const TestToken = await ethers.getContractFactory("TestToken");
  // const testToken = await TestToken.deploy();
  // await testToken.deployed();
  // const testAddress = testToken.address;
  // console.log("TestTokem deployed to:", testAddress);

  //DEXPOOL
  // console.log("Deploying FactoryOneFile");
  // const DexPoolOneFile = await ethers.getContractFactory("DexPoolOneFile");
  // const dexPoolOneFile = await DexPoolOneFile.deploy();
  // // const dexPoolOneFile = await DexPoolOneFile.deploy("0xE3BC9A5B6edC1a113a33613208003d00C696aAeb");
  // await dexPoolOneFile.deployed();
  // const dexAddress = dexPoolOneFile.address;
  // console.log("DexPoolOneFile deployed to:", dexAddress);


  console.log("Deploying CBridge: ");
  const CBridgeUSDT = await ethers.getContractFactory("CBridgeUSDT");
  const cBridgeUSDT = await CBridgeUSDT.deploy();
  await cBridgeUSDT.deployed();
  const tokenAddress = cBridgeUSDT.address;
  console.log("cBridgeUSDT deployed to: ", tokenAddress)
  
}
  
  // We recommend this pattern to be able to use async/await everywhere
  // and properly handle errors.
  main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
  
