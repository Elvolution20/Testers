// Apply configuration
// require('@openzeppelin/test-helpers/configure')({ ... });

// // Import the helpers
// const { expectRevert } = require('@openzeppelin/test-helpers');

// require('@openzeppelin/test-helpers/configure')({
//   singletons: {
//     abstraction: 'web3',
//     defaultGas: 6e6,
//     defaultSender: '0x5a0b5...',
//   },
// });

// require('@openzeppelin/test-helpers/configure')({
//   provider: web3.currentProvider,
//   singletons: {
//     abstraction: 'truffle',
//   },
// });
// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
// require('@nomiclabs/hardhat-ethers');
// const { ethers, upgrades } = require('hardhat');
const Web3 = require("web3");
// require('@openzeppelin/hardhat-upgrades');
// import hre from 'hardhat';

// const Four = artifacts.require("Four");
// const Farmer = artifacts.require("Farmer");

async function main() {
    // const itx = new ethers.providers.InfuraProvider(
    //   'rinkeby', // or 'ropsten', 'mainnet', 'kovan', 'goerli'
    //   'db617577f01f43ea9d89f2aa19cd5363'
    // );

    // const signer = new ethers.Wallet('', itx)
    // async function getBalance() {
    //   response = await itx.send('relay_getBalance', [signer.address])
    //   console.log(`Your current ITX balance is ${response.balance}`)
    // }
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.
    //
    // If this script is run directly using `node` you may want to call compile
    // manually to make sure everything is compiled
    // await hre.run('compile');
    
    // We get the contract to deploy
    //Normal deployment
    // console.log(upgrades);
    // console.log(ethers);
    const Farmer = await ethers.getContractFactory("FarmerUpg");
    const upgfarm = await hre.upgrades.deployProxy(Farmer, { kind: 'uups' });
    console.log("FARM:",Farmer);
    console.log("UPG:", upgfarm);
    await upgfarm.deployed();
    // await instance.functions.initialize();
    const fadd = (await upgfarm).address;
    console.log("FADDRESS: ", fadd);
    // console.log("UpgFADDRESS: ", instance);
    
    
    const FourUpg = await ethers.getContractFactory("FourUpg");
    const upgInstance = await upgrades.deployProxy(FourUpg, [fadd], { initializer: 'initialize' });
    const v1Instance = await upgInstance.deployed();
    const TSUPPLY = await v1Instance.functions.totalSupply();
    // await v1Instance.functions.initialize("0x5FbDB2315678afecb367f032d93F642f64180aa3");
    const bal = await v1Instance.functions.balanceOf(fadd);
    console.log("BAL: ", Web3.utils.hexToNumberString(bal[0]._hex));
    console.log("TSUPPLY: ", Web3.utils.hexToNumberString(TSUPPLY[0]._hex));
    console.log("Symbol: ", await v1Instance.functions.symbol());
    console.log("Name: ", await v1Instance.functions.name());
    // console.log("DINSTANCE: ", v1Instance);
    // console.log("DINSTANCE: ", v1Instance);
    
    //To upgrade
    // const FourUpgV2 = await ethers.getContractFactory("FourUpgV2");
    // const v2 = await upgrades.upgradeProxy(v1Instance.address, FourUpgV2);
    // // console.log("V2:", v2);
    // console.log("SymbolUpg: ", await v2.functions.symbol());
    // console.log("NameUpg: ", await v2.functions.name());
    
    // console.log("DEP: ",esg);
    // console.log("NAME: ",_name);
    // console.log("Name: ",name);
    // console.log("Greeter deployed to:", fourToken.address);
  }
  
  // We recommend this pattern to be able to use async/await everywhere
  // and properly handle errors.
  main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
  
  // const provider = new ethers.providers.JsonRpcProvider("https://rinkeby.infura.io/v3/db617577f01f43ea9d89f2aa19cd.......");
  // const signer = provider.getSigner();
  
  // it('works before and after upgrading', async function () {
    //   const instance = await upgrades.deployProxy(Box, [42]);
    //   assert.strictEqual(await instance.retrieve(), 42);
    
    //   await upgrades.upgradeProxy(instance.address, BoxV2);
    //   assert.strictEqual(await instance.retrieve(), 42);
    // });const { ethers } = require('ethers')
    
    
    // async function callContract() {
      //   const iface = new ethers.utils.Interface(['function echo(string message)'])
      //   const data = iface.encodeFunctionData('echo', ['Hello world!'])
      //   const tx = {
        //     to: '0x6663184b3521bF1896Ba6e1E776AB94c317204B6',
        //     data: data,
        //     gas: '100000',
        //     schedule: 'fast'
        //   }
        //   const signature = await signRequest(tx)
//   const relayTransactionHash = await itx.send('relay_sendTransaction', [
//     tx,
//     signature
//   ])
//   console.log(`ITX relay hash: ${relayTransactionHash}`)
//   return relayTransactionHash
// }


// let web3 = new Web3(
//   // Replace YOUR-PROJECT-ID with a Project ID from your Infura Dashboard
//   new Web3.providers.WebsocketProvider("wss://rinkeby.infura.io/ws/v3/db617577f01f43ea9d89f2aa19cd")
// );
//   const instance = new web3.eth.Contract(fo, <address>);
//     {/* await deployer.deploy(Farmer);
//     const dpFarmer = await Farmer.deployed();
//     const addrFarmer = dpFarmer.address;

//     await deployer.deploy(Four, dpFarmer.address);
//     const dpFour = await Four.deployed();
//     const addrFour = dpFour.address; */}

    
// instance.getPastEvents(
//     "SomeEvent",
//     { fromBlock: "latest", toBlock: "latest" },
//     (errors, events) => {
//         if (!errors) {
//             // process events
//         }
// );




//Test helper

// const {
//   BN,           // Big Number support
//   constants,    // Common constants, like the zero address and largest integers
//   expectEvent,  // Assertions for emitted events
//   expectRevert, // Assertions for transactions that should fail
// } = require('@openzeppelin/test-helpers');

// const ERC20 = artifacts.require('ERC20');

// describe('ERC20', function ([sender, receiver]) {
//   beforeEach(async function () {
//     // The bundled BN library is the same one web3 uses under the hood
//     this.value = new BN(1);

//     this.erc20 = await ERC20.new();
//   });

//   it('reverts when transferring tokens to the zero address', async function () {
//     // Conditions that trigger a require statement can be precisely tested
//     await expectRevert(
//       this.erc20.transfer(constants.ZERO_ADDRESS, this.value, { from: sender }),
//       'ERC20: transfer to the zero address',
//     );
//   });

//   it('emits a Transfer event on successful transfers', async function () {
//     const receipt = await this.erc20.transfer(
//       receiver, this.value, { from: sender }
//     );

//     // Event assertions can verify that the arguments are the expected ones
//     expectEvent(receipt, 'Transfer', {
//       from: sender,
//       to: receiver,
//       value: this.value,
//     });
//   });

//   it('updates balances on successful transfers', async function () {
//     this.erc20.transfer(receiver, this.value, { from: sender });

//     // BN assertions are automatically available via chai-bn (if using Chai)
//     expect(await this.erc20.balanceOf(receiver))
//       .to.be.bignumber.equal(this.value);
//   });
// });