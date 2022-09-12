const { parseUnits } = require("ethers/lib/utils");
const { ethers, upgrades } = require("hardhat");
const { getUSDC, getBUSD, getUSDT, deploy, parseUniform, deployProxy } = require("../utils");

module.exports = {
  setupTokens, setupCore, deployFakeStrategy,
  setupFakeTokens, setupTokensLiquidityOnPancake, setupParamsOnBNB, setupTestParams, setupRouterParams,
  setupFakePrices, setupPancakePlugin
};

async function deployFakeStrategy({ router, token, weight = 10_000, profitPercent = 10_000 }) {
  // console.log(router.address, await token.name(), weight, profitPercent);
  let strategy = await deploy("MockStrategy", token.address, profitPercent);
  await strategy.transferOwnership(router.address);
  await router.addStrategy(strategy.address, token.address, weight);
}

// Deploy TestCurrencies and mint totalSupply to the 'owner'
async function setupFakeTokens() {

  // each test token's total supply, minted to owner
  let totalSupply = (100_000_000).toString();

  let parseUsdc = (args) => parseUnits(args, 18);
  let usdc = await deploy("MockToken", parseUsdc(totalSupply), 18);

  let parseBusd = (args) => parseUnits(args, 8);
  let busd = await deploy("MockToken", parseBusd(totalSupply), 8);

  let parseUsdt = (args) => parseUnits(args, 6);
  let usdt = await deploy("MockToken", parseUsdt(totalSupply), 6);

  return { usdc, busd, usdt, parseUsdc, parseBusd, parseUsdt };

};

// Create liquidity on uniswap-like router with test tokens
async function setupTokensLiquidityOnPancake(tokenA, tokenB, amount) {
  const [owner, feeAddress] = await ethers.getSigners();
  // let uniswapRouter = await ethers.getContractAt("IUniswapV2Router02", hre.networkVariables.uniswapRouter);
  let weth = await deploy("WETH");
  let factory = await deploy("UniswapV2Factory", feeAddress.address);
  let uniswapRouter = await deploy("UniswapV2Router02", factory.address, weth.address);

  let amountA = parseUnits(amount, await tokenA.decimals());
  let amountB = parseUnits(amount, await tokenB.decimals());
  await tokenA.approve(uniswapRouter.address, amountA);
  await tokenB.approve(uniswapRouter.address, amountB);
  await uniswapRouter.addLiquidity(
    tokenA.address,
    tokenB.address,
    amountA,
    amountB,
    0,
    0,
    owner.address,
    Date.now()
  );
};


// Get tokens that actually exists on BNB for testing
async function setupTokens() {
  ({ tokenContract: usdc, parse: parseUsdc } = await getUSDC());
  ({ tokenContract: usdt, parse: parseUsdt } = await getUSDT());
  ({ tokenContract: busd, parse: parseBusd } = await getBUSD());
  return { usdc, busd, usdt, parseUsdc, parseUsdt, parseBusd };
};

// deploy core contracts
async function setupCore() {

  // Deploy Oracle 
  let oracle = await deploy("FakeOracle");
  // Deploy Exchange 
  // let exchange = await deployProxy("Exchange");
  let exchange = await deploy("ExchangeOnefile");
  // Deploy Batch
  // let batch = await deployProxy("BatchOnefile");
  let batch = await deploy("BatchOnefile");
  // Deploy StrategyRouterLib 
  let routerLib = await deploy("contracts/verify/StrategyRouterOneFile.sol:StrategyRouterLib");
  // Deploy StrategyRouter 
  let StrategyRouter = await ethers.getContractFactory("StrategyRouterOnefile", {
    libraries: {
      StrategyRouterLib: routerLib.address
    }
  });

  // let router = await upgrades.deployProxy(StrategyRouter, [], {
  //   kind: 'uups',
  // });
  let router = await StrategyRouter.deploy();
  await router.deployed();
  // Deploy SharesToken
  // let sharesToken = await deployProxy("SharesToken", [router.address]);
  let sharesToken = await deploy("SharesTokenOnefile", router.address);
  // Deploy  ReceiptNFT
  // let receiptContract = await deployProxy("ReceiptNFT", [router.address, batch.address]);
  let receiptContract = await deploy("ReceiptNFTOnefile", router.address, batch.address);

  // set addresses
  await router.setAddresses(
    exchange.address,
    oracle.address,
    sharesToken.address,
    batch.address,
    receiptContract.address
  );
  await batch.setAddresses(
    exchange.address,
    oracle.address,
    router.address,
    receiptContract.address
  );

  // Retrieve contracts that are deployed from StrategyRouter constructor
  let INITIAL_SHARES = Number(1e12);

  return { oracle, exchange, router, receiptContract, batch, sharesToken, INITIAL_SHARES };
}

// Setup core params for testing with MockToken
async function setupTestParams(router, oracle, exchange, usdc, usdt, busd) {

  const [owner,,,,,,,,,feeAddress] = await ethers.getSigners();
  // Setup router params
  await router.setMinUsdPerCycle(parseUniform("0.9"));
  await router.setFeesPercent(2000);
  await router.setFeesCollectionAddress(feeAddress.address);
  await router.setCycleDuration(1);

  // Setup fake prices
  let usdtAmount = parseUnits("0.99", await usdt.decimals());
  await oracle.setPrice(usdt.address, usdtAmount);
  let busdAmount = parseUnits("1.01", await busd.decimals());
  await oracle.setPrice(busd.address, busdAmount);
  let usdcAmount = parseUnits("1.0", await usdc.decimals());
  await oracle.setPrice(usdc.address, usdcAmount);

  let clip = hre.networkVariables.clip;

  let pancakePlugin = await deploy("UniswapPlugin");
  let pancake = (pancakePlugin).address;
  // Setup exchange params
  busd = busd.address;
  usdc = usdc.address;
  usdt = usdt.address;
  await exchange.setRoute(
    [busd, busd, usdc, clip, clip, clip],
    [usdt, usdc, usdt, busd, usdt, usdc],
    [pancake, pancake, pancake, pancake, pancake, pancake]
  );

  // pancake plugin params
  await pancakePlugin.setUniswapRouter(hre.networkVariables.uniswapRouter);
  // await pancakePlugin.setUseWeth(clip, busd, true);
  // await pancakePlugin.setUseWeth(clip, usdt, true);
  // await pancakePlugin.setUseWeth(clip, usdc, true);

}

async function setupRouterParams(router, oracle, exchange) {

  const [owner, feeAddress] = await ethers.getSigners();
  // Setup router params
  await router.setMinUsdPerCycle(parseUniform("0.9"));
  await router.setFeesPercent(2000);
  await router.setFeesCollectionAddress(feeAddress.address);
  await router.setCycleDuration(1);
}

async function setupFakePrices(oracle, usdc, usdt, busd) {
  // Setup fake prices
  let usdtAmount = parseUnits("0.99", await usdt.decimals());
  await oracle.setPrice(usdt.address, usdtAmount);
  let busdAmount = parseUnits("1.01", await busd.decimals());
  await oracle.setPrice(busd.address, busdAmount);
  let usdcAmount = parseUnits("1.0", await usdc.decimals());
  await oracle.setPrice(usdc.address, usdcAmount);
}

async function setupPancakePlugin(exchange, usdc, usdt, busd) {
  let clip = hre.networkVariables.clip;

  let pancakePlugin = await deploy("UniswapPlugin");
  let pancake = (pancakePlugin).address;
  // Setup exchange params
  busd = busd.address;
  usdc = usdc.address;
  usdt = usdt.address;
  await exchange.setRoute(
      [busd, busd, usdc, clip, clip, clip],
      [usdt, usdc, usdt, busd, usdt, usdc],
      [pancake, pancake, pancake, pancake, pancake, pancake]
  );

  // pancake plugin params
  await pancakePlugin.setUniswapRouter(hre.networkVariables.uniswapRouter);
  // await pancakePlugin.setUseWeth(clip, busd, true);
  // await pancakePlugin.setUseWeth(clip, usdt, true);
  // await pancakePlugin.setUseWeth(clip, usdc, true);
}

// Setup core params that are similar (or the same) as those that will be set in production
async function setupParamsOnBNB(router, oracle, exchange) {
  const [owner,,,,,,,,,,feeAddress] = await ethers.getSigners();
  // Setup router params
  await router.setMinUsdPerCycle(parseUniform("0.9"));
  await router.setFeesPercent(2000);
  await router.setFeesCollectionAddress(feeAddress.address);
  await router.setCycleDuration(1);

  await setupPluginsOnBNB(exchange);
}

async function setupPluginsOnBNB(exchange) {

  let clip = hre.networkVariables.clip;
  let busd = hre.networkVariables.busd;
  let usdt = hre.networkVariables.usdt;
  let usdc = hre.networkVariables.usdc;
  let acs4usd = hre.networkVariables.acs4usd.address;

  let acsPlugin = await deploy("CurvePlugin");
  let pancakePlugin = await deploy("UniswapPlugin");

  // Setup exchange params
  await exchange.setRoute(
    [busd, busd, usdc, clip, clip, clip],
    [usdt, usdc, usdt, busd, usdt, usdc],
    [acsPlugin.address, acsPlugin.address, acsPlugin.address, 
      pancakePlugin.address, pancakePlugin.address, pancakePlugin.address]
  );

  // acs plugin params
  await acsPlugin.setCurvePool(busd, usdt, acs4usd);
  await acsPlugin.setCurvePool(usdc, usdt, acs4usd);
  await acsPlugin.setCurvePool(busd, usdc, acs4usd);
  await acsPlugin.setCoinIds(
    hre.networkVariables.acs4usd.address,
    hre.networkVariables.acs4usd.tokens,
    hre.networkVariables.acs4usd.coinIds
  );

  // pancake plugin params
  await pancakePlugin.setUniswapRouter(hre.networkVariables.uniswapRouter);
  await pancakePlugin.setUseWeth(clip, busd, true);
  await pancakePlugin.setUseWeth(clip, usdt, true);
  await pancakePlugin.setUseWeth(clip, usdc, true);
}