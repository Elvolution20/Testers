const StrategyRouter = artifacts.require("StrategyRouter");
const StrategyRouterLib = artifacts.require("StrategyRouterLib");
const StargateStrategy = artifacts.require("StargateStrategy");
const DodoStrategy = artifacts.require("DodoStrategy");

module.exports = async function (deployer) {
  // const strategyrouterLib = await deployer.deploy(StrategyRouterLib);
  // // await strategyrouterLib.deployed();
  // // const address1 = strategyrouterLib.address;
  // console.log("strategyRouterLib", strategyrouterLib );

  // deployer.link(StrategyRouterLib, [StrategyRouter]);
  // const strategyRouter = await deployer.deploy(StrategyRouter);
  // // await strategyRouter.deployed();
  // // const address2 = strategyRouter.address;
  // console.log("strategyRouter", strategyRouter );

  // const stargateStrategy = await deployer.deploy(StargateStrategy);
  // // const address3 = stargateStrategy.address;
  // // stargateStrategy.deployed();
  // console.log("strategyRouter", stargateStrategy );

  const dodoStrategy = await deployer.deploy(DodoStrategy);
  // const address4 = dodoStrategy.address;
  // await dodoStrategy.deployed();
  console.log("strategyRouter", dodoStrategy);

};
