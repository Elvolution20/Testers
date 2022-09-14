const { expect, assert } = require("chai");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");
const { deploy } = require("./utils");
const { parseUnits } = require("ethers/lib/utils");
const { deployMockContract } = require("ethereum-waffle");
const { deployFakeStrategy } = require("./shared/commonSetup");

const parseUniform = (args) => parseUnits(args, 18);

let owner,
  sender,
  feeAddress,
  nonOwner,
  fakePriceFeed,
  fakeToken1,
  fakeToken2,
  fakePriceFeed2,
  fakeToken3,
  fakeToken4;
// mock tokens with different decimals
let usdc, usdt, busd, lpToken;
// helper functions to parse amounts of mock tokens
let parseUsdc, parseBusd, parseUsdt;

let weth, factory, uniswapRouter;

let pancakePlugin;
let pancake;

// core contracts
let router, oracle, exchange, dodoRouter, clip;

// let clip, dodoToken, lpToken, libAddress;
let amountA, amountB;

let receiptNFT, batch, sharesToken;

let totalSupply = (100_000_000).toString();

let value = (1000000000000000000).toString();

let amount = (1_000_000).toString();

// fake prices
let usdtAmount, busdAmount, usdcAmount;

describe("Test Dodostretegy", function () {
  before(async function () {
    [
      owner,
      sender,
      feeAddress,
      nonOwner,
      fakePriceFeed,
      fakeToken1,
      fakeToken2,
      fakePriceFeed2,
      fakeToken3,
      fakeToken4,
    ] = await ethers.getSigners();
    // usdc = await deploy("MockToken", parseUsdc(totalSupply), 18, "USDC Token", "USDC");
    // busd = await deploy("MockToken", parseBusd(totalSupply), 8, "BUSD Token", "BUSD");
    // usdt = await deploy("MockToken", parseUsdt(totalSupply), 6, "USDT Token", "USDT");
    // await setupFakeTokens();
    await setupCore();
    // setupFakePrices();
    // setupTestParams();
    // setupTokensLiquidityOnPancake(amount);
    // setupPancakePlugin();
    await busd.approve(router.address, parseBusd("1000000"));
    await usdc.approve(router.address, parseUsdc("1000000"));
    await usdt.approve(router.address, parseUsdt("1000000"));
    // setupRouterParams(router, oracle, exchange, owner, feeAddress);
  });

  // beforeEach(async () => {
  //   snapshotId = await provider.send("evm_snapshot");
  // });

  // afterEach(async () => {
  //   await provider.send("evm_revert", [snapshotId]);
  // });

  // after(async () => {
  //   await provider.send("evm_revert", [initialSnapshot]);
  // });

  describe("Test rebalanceBatch function", function () {
    it("usdt strategy, router supports only usdt, should revert", async function () {
      // await router.topUp({value: value});

      await router.setSupportedToken(usdt.address, true);

      let farm = await createMockStrategy(usdt.address, (10000).toString());
      await router.addStrategy(
        dodoRouter.address,
        usdt.address,
        (5000).toString()
      );

      // await expect(router.rebalanceBatch()).to.be.revertedWith("NothingToRebalance()");
    });

    it("should setPriceFeeds be onlyOwner", async function () {
      await expect(
        oracle.connect(nonOwner).setPriceFeeds([], [])
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("should setPriceFeeds store feed address", async function () {
      let tokens = [fakeToken1.address, fakeToken2.address];
      let feeds = [fakePriceFeed.address, fakePriceFeed2.address];
      await oracle.setPriceFeeds(tokens, feeds);
      expect(await oracle.feeds(fakeToken1.address)).to.be.eq(
        fakePriceFeed.address
      );
    });

    it("should getAssetUsdPrice revert on stale price", async function () {
      let mockFeed = await getMockFeed();

      let tokens = [fakeToken1.address];
      let feeds = [mockFeed.address];
      await oracle.setPriceFeeds(tokens, feeds);

      // roundId = 0, answer = 0, startedAt = 0, updatedAt = 0, answeredInRound = 0
      await mockFeed.mock.latestRoundData.returns(0, 0, 0, 0, 0);
      await expect(
        oracle.getTokenUsdPrice(fakeToken1.address)
      ).to.be.revertedWith("StaleChainlinkPrice()");
    });

    it("should getAssetUsdPrice revert on 0 price", async function () {
      let mockFeed = await getMockFeed();

      let tokens = [fakeToken1.address];
      let feeds = [mockFeed.address];
      await oracle.setPriceFeeds(tokens, feeds);

      // roundId = 0, answer = 0, startedAt = 0, updatedAt = 0, answeredInRound = 0
      let timestamp = (await provider.getBlock()).timestamp;
      await mockFeed.mock.latestRoundData.returns(0, 0, 0, timestamp, 0);

      await expect(
        oracle.getTokenUsdPrice(fakeToken1.address)
      ).to.be.revertedWith("BadPrice()");
    });

    it("should getAssetUsdPrice return price and price decimals", async function () {
      let mockFeed = await getMockFeed();

      let tokens = [fakeToken1.address];
      let feeds = [mockFeed.address];
      await oracle.setPriceFeeds(tokens, feeds);

      // roundId = 0, answer = 0, startedAt = 0, updatedAt = 0, answeredInRound = 0
      let timestamp = (await provider.getBlock()).timestamp;
      let price = 1337;
      let decimals = 18;
      await mockFeed.mock.latestRoundData.returns(0, price, 0, timestamp, 0);
      await mockFeed.mock.decimals.returns(decimals);

      let returnData = await oracle.getTokenUsdPrice(fakeToken1.address);
      expect(returnData.price).to.be.equal(price);
      expect(returnData.decimals).to.be.equal(decimals);
    });

    it("usdt strategy, router supports multiple arbitrary tokens", async function () {
      // add fake strategies
      await deployFakeStrategy({ router, token: busd });
      await deployFakeStrategy({ router, token: usdc });
      await deployFakeStrategy({ router, token: usdt });

      // admin initial deposit to set initial shares and pps
      await router.depositToBatch(busd.address, parseBusd("1"));
      await router.allocateToStrategies();

      // await router.setSupportedToken(usdt.address, true);
      await router.setSupportedToken(busd.address, true);
      await router.setSupportedToken(usdc.address, true);

      let farm = await createMockStrategy(usdt.address, 10000);
      await router.addStrategy(farm.address, usdt.address, 5000);

      await router.depositToBatch(usdt.address, parseUsdt("1"));
      await router.depositToBatch(busd.address, parseBusd("1"));
      await router.depositToBatch(usdc.address, parseUsdc("1"));

      await verifyTokensRatio([1, 1, 1]);

      let ret = await router.callStatic.rebalanceBatch();
      let gas = (await (await router.rebalanceBatch()).wait()).gasUsed;
      // console.log("gasUsed", gas);
      // console.log("ret", ret);
      // console.log("getTokenBalances", await getTokenBalances());

      await verifyTokensRatio([1, 0, 0]);
    });

    it("two usdt strategies, router supports only usdt", async function () {
      await router.setSupportedToken(usdt.address, true);

      let farm = await createMockStrategy(usdt.address, 10000);
      let farm2 = await createMockStrategy(usdt.address, 10000);
      await router.addStrategy(farm.address, usdt.address, 5000);
      await router.addStrategy(farm2.address, usdt.address, 5000);

      await router.depositToBatch(usdt.address, parseUsdt("1"));

      let ret = await router.callStatic.rebalanceBatch();
      await verifyRatioOfReturnedData([1, 1], ret);

      let gas = (await (await router.rebalanceBatch()).wait()).gasUsed;
      // console.log("gasUsed", gas);
      // console.log("ret", ret);
      // console.log("getTokenBalances", await getTokenBalances());
    });

    it("two usdt strategies, router supports usdt,busd,usdc", async function () {
      await router.setSupportedToken(usdt.address, true);
      await router.setSupportedToken(busd.address, true);
      await router.setSupportedToken(usdc.address, true);

      let farm = await createMockStrategy(usdt.address, 10000);
      let farm2 = await createMockStrategy(usdt.address, 10000);
      await router.addStrategy(farm.address, usdt.address, 5000);
      await router.addStrategy(farm2.address, usdt.address, 5000);

      await router.depositToBatch(usdt.address, parseUsdt("1"));
      await router.depositToBatch(busd.address, parseBusd("1"));
      await router.depositToBatch(usdc.address, parseUsdc("1"));
      // console.log(await router.getBatchValueUsd());

      await verifyTokensRatio([1, 1, 1]);

      let ret = await router.callStatic.rebalanceBatch();
      await verifyRatioOfReturnedData([1, 1], ret);

      let gas = (await (await router.rebalanceBatch()).wait()).gasUsed;
      // console.log("gasUsed", gas);

      await verifyTokensRatio([1, 0, 0]);
    });

    it("usdt and busd strategies, router supports usdt,busd", async function () {
      await router.setSupportedToken(usdt.address, true);
      await router.setSupportedToken(busd.address, true);

      let farm = await createMockStrategy(usdt.address, 10000);
      let farm2 = await createMockStrategy(busd.address, 10000);
      await router.addStrategy(farm2.address, busd.address, 5000);
      await router.addStrategy(farm.address, usdt.address, 5000);

      await router.depositToBatch(usdt.address, parseUsdt("2"));
      await router.depositToBatch(busd.address, parseBusd("1"));

      await verifyTokensRatio([2, 1]);

      let ret = await router.callStatic.rebalanceBatch();
      // console.log(ret);
      await verifyRatioOfReturnedData([1, 1], ret);

      let gas = (await (await router.rebalanceBatch()).wait()).gasUsed;
      // console.log("gasUsed", gas);

      await verifyTokensRatio([1, 1]);
    });

    it("usdt and busd strategies, router supports usdt,busd,usdc", async function () {
      await router.setSupportedToken(busd.address, true);
      await router.setSupportedToken(usdc.address, true);
      await router.setSupportedToken(usdt.address, true);

      let farm = await createMockStrategy(usdt.address, 10000);
      let farm2 = await createMockStrategy(busd.address, 10000);

      await router.addStrategy(farm2.address, busd.address, 7000);
      await router.addStrategy(farm.address, usdt.address, 3000);

      await router.depositToBatch(usdt.address, parseUsdt("2201"));
      await router.depositToBatch(busd.address, parseBusd("923"));
      await router.depositToBatch(usdc.address, parseUsdc("3976"));

      await verifyTokensRatio([13, 56, 31]);

      let ret = await router.callStatic.rebalanceBatch();
      // console.log(ret);
      await verifyRatioOfReturnedData([7, 3], ret);

      let gas = (await (await router.rebalanceBatch()).wait()).gasUsed;
      // console.log("gasUsed", gas);

      await verifyTokensRatio([70, 0, 30]);
    });

    it("'dust' token balances should not be swapped on dexes", async function () {
      await router.setSupportedToken(busd.address, true);
      await router.setSupportedToken(usdc.address, true);
      await router.setSupportedToken(usdt.address, true);

      let farm = await createMockStrategy(usdt.address, 10000);
      await router.addStrategy(farm.address, usdt.address, 5000);

      await router.depositToBatch(usdt.address, 2);
      await router.depositToBatch(busd.address, 2);
      await router.depositToBatch(usdc.address, parseUsdc("1"));

      let ret = await router.callStatic.rebalanceBatch();
      await expect(ret[0]).to.be.closeTo(parseUsdt("1"), parseUsdt("0.01"));

      let gas = (await (await router.rebalanceBatch()).wait()).gasUsed;

      await verifyTokensRatio([0, 0, 1]);
    });
  });

  describe("Test rebalanceStrategies function", function () {
    it("one strategy rebalance should revert", async function () {
      await router.setSupportedToken(usdt.address, true);

      let farm = await createMockStrategy(usdt.address, 10000);
      await router.addStrategy(farm.address, usdt.address, 5000);

      await expect(router.rebalanceStrategies()).to.be.revertedWith(
        "NothingToRebalance()"
      );
    });

    it("two usdt strategies", async function () {
      await router.setSupportedToken(usdt.address, true);

      let farm = await createMockStrategy(usdt.address, 10000);
      let farm2 = await createMockStrategy(usdt.address, 10000);
      await router.addStrategy(farm.address, usdt.address, 5000);
      await router.addStrategy(farm2.address, usdt.address, 5000);

      await router.depositToBatch(usdt.address, parseUsdt("1"));
      await router.allocateToStrategies();
      await router.updateStrategy(0, 10000);

      await verifyStrategiesRatio([1, 1]);
      let ret = await router.callStatic.rebalanceStrategies();

      let gas = (await (await router.rebalanceStrategies()).wait()).gasUsed;

      await verifyStrategiesRatio([2, 1]);
    });

    it("usdt and busd strategies", async function () {
      await router.setSupportedToken(usdt.address, true);
      await router.setSupportedToken(busd.address, true);

      let farm = await createMockStrategy(usdt.address, 10000);
      let farm2 = await createMockStrategy(busd.address, 10000);
      await router.addStrategy(farm2.address, busd.address, 5000);
      await router.addStrategy(farm.address, usdt.address, 5000);

      await router.depositToBatch(usdt.address, parseUsdt("2"));
      await router.depositToBatch(busd.address, parseBusd("1"));
      await router.allocateToStrategies();

      await router.updateStrategy(0, 10000);

      await verifyStrategiesRatio([1, 1]);

      let gas = (await (await router.rebalanceStrategies()).wait()).gasUsed;
      // console.log("gasUsed", gas);

      await verifyStrategiesRatio([2, 1]);
    });

    it("usdt,usdt,busd strategies", async function () {
      await router.setSupportedToken(usdt.address, true);
      await router.setSupportedToken(busd.address, true);

      let farm = await createMockStrategy(usdt.address, 10000);
      let farm2 = await createMockStrategy(busd.address, 10000);
      let farm3 = await createMockStrategy(usdt.address, 10000);
      await router.addStrategy(farm2.address, busd.address, 5000);
      await router.addStrategy(farm.address, usdt.address, 5000);
      await router.addStrategy(farm3.address, usdt.address, 5000);

      await router.depositToBatch(usdt.address, parseUsdt("2"));
      await router.depositToBatch(busd.address, parseBusd("1"));
      await router.allocateToStrategies();

      await verifyStrategiesRatio([1, 1, 1]);

      await router.updateStrategy(0, 10000);
      await router.updateStrategy(2, 10000);

      let gas = (await (await router.rebalanceStrategies()).wait()).gasUsed;
      // console.log("gasUsed", gas);

      await verifyStrategiesRatio([2, 1, 2]);
    });

    it("'dust' amounts should be ignored and not swapped on dex", async function () {
      await router.setSupportedToken(busd.address, true);
      await router.setSupportedToken(usdc.address, true);
      await router.setSupportedToken(usdt.address, true);

      let farm = await createMockStrategy(usdt.address, 10000);
      let farm2 = await createMockStrategy(busd.address, 10000);
      let farm3 = await createMockStrategy(usdt.address, 10000);
      await router.addStrategy(farm2.address, busd.address, 5000);
      await router.addStrategy(farm.address, usdt.address, 5000);
      await router.addStrategy(farm3.address, usdt.address, 5000);

      await router.depositToBatch(usdt.address, 2);
      await router.depositToBatch(busd.address, 2);
      await router.depositToBatch(usdc.address, parseUsdc("1"));

      await router.allocateToStrategies();

      await router.updateStrategy(0, 10000);
      await router.updateStrategy(1, 10001);
      await router.updateStrategy(2, 10001); // notice 1 in the end

      await verifyStrategiesRatio([1, 1, 1]);

      let gas = (await (await router.rebalanceStrategies()).wait()).gasUsed;
      // console.log("gasUsed", gas);

      await verifyStrategiesRatio([1, 1, 1]);
    });
  });

  async function verifyRatioOfReturnedData(weights, data) {
    assert(Number(await router.getStrategiesCount()) == weights.length);
    let balances = Array.from(data);
    let totalDeposit = BigNumber.from(0);
    let strategies = await router.getStrategies();

    for (let i = 0; i < balances.length; i++) {
      let uniformAmount = await toUniform(
        balances[i],
        strategies[i].depositToken
      );
      balances[i] = uniformAmount;
      totalDeposit = totalDeposit.add(uniformAmount);
    }
    let totalWeight = weights.reduce((e, acc) => acc + e);
    const ERROR_THRESHOLD = 0.3;
    for (let i = 0; i < weights.length; i++) {
      const percentWeight = (weights[i] * 100) / totalWeight;
      const percentBalance = (balances[i] * 100) / totalDeposit;
      expect(percentBalance).to.be.closeTo(percentWeight, ERROR_THRESHOLD);
    }
  }
  async function toUniform(amount, tokenAddress) {
    let decimals = await (
      await ethers.getContractAt("ERC20", tokenAddress)
    ).decimals();
    return await changeDecimals(amount, Number(decimals), Number(18));
  }

  async function changeDecimals(amount, oldDecimals, newDecimals) {
    if (oldDecimals < newDecimals) {
      return amount.mul(BigNumber.from(10).pow(newDecimals - oldDecimals));
      // return amount * (10 ** (newDecimals - oldDecimals));
    } else if (oldDecimals > newDecimals) {
      return amount.div(BigNumber.from(10).pow(oldDecimals - newDecimals));
      // return amount / (10 ** (oldDecimals - newDecimals));
    }
    return amount;
  }

  // weights order should match 'tokens' order
  async function verifyTokensRatio(weights) {
    assert((await router.getSupportedTokens()).length == weights.length);
    const ERROR_THRESHOLD = 0.6;
    const { total: totalUsd, balances: tokenBalancesUsd } =
      await getTokenBalances();
    let totalWeight = weights.reduce((e, acc) => acc + e);
    // console.log("Total weight: " + totalWeight);
    let totalWeightsSum = 0;
    for (let i = 0; i < weights.length; i++) {
      const percentWeight = (weights[i] * 100) / totalWeight;
      // console.log("Percent weight: " + percentWeight);
      // console.log("Token balance USD: " + tokenBalancesUsd[i])
      // console.log("Total USD: " + totalUsd);
      const percentBalance = (tokenBalancesUsd[i] * 100) / totalUsd;
      // console.log("Percent balance: " + percentBalance);
      expect(percentBalance).to.be.closeTo(percentWeight, ERROR_THRESHOLD);
      totalWeightsSum += percentBalance;
      // console.log("-- Cycle #" + i + " passed, starting next cycle #" + (i+1));
    }
    expect(totalWeightsSum).to.be.closeTo(100, 0.1);
  }

  async function verifyStrategiesRatio(weights) {
    assert((await router.getStrategiesCount()) == weights.length);
    const ERROR_THRESHOLD = 0.5;
    const { total, balances } = await getStrategiesBalances();
    let totalWeight = weights.reduce((e, acc) => acc + e);
    for (let i = 0; i < weights.length; i++) {
      const percentWeight = (weights[i] * 100) / totalWeight;
      const percentBalance = (balances[i] * 100) / total;
      expect(percentBalance).to.be.closeTo(percentWeight, ERROR_THRESHOLD);
    }
  }

  async function getTokenBalances() {
    let [total, balances] = await router.getBatchValueUsd();
    return { total, balances };
  }

  async function getStrategiesBalances() {
    let strategies = await router.getStrategies();
    let total = BigNumber.from(0);
    let balances = [];
    for (let i = 0; i < strategies.length; i++) {
      const stratAddr = strategies[i].strategyAddress;
      let strategy = await ethers.getContractAt("IStrategy", stratAddr);
      let balance = await toUniform(
        await strategy.totalTokens(),
        strategies[i].depositToken
      );
      total = total.add(BigNumber.from(balance));
      balances.push(balance);
    }
    return { total, balances };
  }

  async function createMockStrategy(depositToken, profit_percent) {
    let _farm = await deploy("MockStrategy", depositToken, profit_percent);
    return _farm;
  }

  async function getMockFeed() {
    const abi = (
      await artifacts.readArtifact(
        "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol:AggregatorV3Interface"
      )
    ).abi;
    const mock = await deployMockContract(owner, abi);
    return mock;
  }

  // // Setup core params for testing with MockToken
  // async function setupTestParams() {

  // }

  // Deploy TestCurrencies and mint totalSupply to the 'owner'
  // async function setupFakeTokens() {

  // };

  // async function setupTokensLiquidityOnPancake(amount) {

  // };

  // deploy core contracts
  async function setupCore() {
    // each test token's total supply, minted to owner
    let totalSupply = (100_000_000).toString();

    parseUsdc = (args) => parseUnits(args, 18);
    usdc = await deploy(
      "MockToken",
      parseUsdc(totalSupply),
      18,
      "USDC Token",
      "USDC"
    );

    parseBusd = (args) => parseUnits(args, 8);
    busd = await deploy(
      "MockToken",
      parseBusd(totalSupply),
      8,
      "BUSD Token",
      "BUSD"
    );

    parseUsdt = (args) => parseUnits(args, 6);
    usdt = await deploy(
      "MockToken",
      parseUsdt(totalSupply),
      6,
      "USDT Token",
      "USDT"
    );

    clip = await deploy(
      "MockToken",
      parseUsdt(totalSupply),
      6,
      "CLIP Token",
      "CLIP"
    );
    // return { usdc, busd, usdt, parseUsdc, parseBusd, parseUsdt };

    weth = await deploy("WETH");
    factory = await deploy("UniswapV2Factory", owner.address);
    uniswapRouter = await deploy(
      "UniswapV2Router02",
      factory.address,
      weth.address
    );
    // Deploy Oracle
    oracle = await deploy("FakeOracle");

    // Deploy Exchange
    // let exchange = await deployProxy("Exchange");
    exchange = await deploy("ExchangeOnefile");

    // Deploy Batch
    // let batch = await deployProxy("BatchOnefile");
    batch = await deploy("BatchOnefile");

    // Deploy StrategyRouterLib
    let routerLib = await deploy(
      "contracts/verify/StrategyRouterOneFile.sol:StrategyRouterLib"
    );

    // Deploy StrategyRouter
    let StrategyRouter = await ethers.getContractFactory(
      "StrategyRouterOnefile",
      {
        libraries: {
          StrategyRouterLib: routerLib.address,
        },
      }
    );

    // let router = await upgrades.deployProxy(StrategyRouter, [], {
    //   kind: 'uups',
    // });
    router = await StrategyRouter.deploy();
    await router.deployed();

    // Deploy SharesToken
    // let sharesToken = await deployProxy("SharesToken", [router.address]);
    sharesToken = await deploy("SharesTokenOnefile", router.address);

    // Deploy  ReceiptNFT
    // let receiptNFT = await deployProxy("ReceiptNFT", [router.address, batch.address]);
    pancakePlugin = await deploy("UniswapPlugin");
    pancake = pancakePlugin.address;

    receiptNFT = await deploy(
      "ReceiptNFTOnefile",
      router.address,
      batch.address
    );
    lpToken = await deploy("Token");

    dodoRouter = await deploy("DodoStrategyOnefile");

    await dodoRouter.initialize(
      router.address,
      1,
      usdt.address,
      busd.address,
      lpToken.address
    );

    // set addresses
    await router.setAddresses(
      exchange.address,
      oracle.address,
      sharesToken.address,
      batch.address,
      receiptNFT.address
    );

    await batch.setAddresses(
      exchange.address,
      oracle.address,
      router.address,
      receiptNFT.address
    );

    // Setup fake prices
    usdtAmount = parseUnits("0.99", await usdt.decimals());
    await oracle.setPrice(usdt.address, usdtAmount);

    busdAmount = parseUnits("1.01", await busd.decimals());
    await oracle.setPrice(busd.address, busdAmount);

    usdcAmount = parseUnits("1.0", await usdc.decimals());
    await oracle.setPrice(usdc.address, usdcAmount);

    // Retrieve contracts that are deployed from StrategyRouter constructor
    INITIAL_SHARES = Number(1e12);

    // return {
    //   oracle:_oracle,
    //   exchange:_exchange,
    //   router:_router,
    //   receiptNFT:_receiptNFT,
    //   batch:_batch,
    //   sharesToken: _sharesToken,
    //   dodoRouter: _dodoRouter,
    //   INITIAL_SHARES
    // };

    // const [owner,,,,,,,,,feeAddress] = await ethers.getSigners();
    // Setup router params
    await router.setMinUsdPerCycle(parseUniform("0.9"));
    await router.setFeesPercent(2000);
    await router.setFeesCollectionAddress(feeAddress.address);
    await router.connect(owner).setCycleDuration(1);

    // let pancakePlugin = await deploy("UniswapPlugin");
    // let pancake = pancakePlugin.address;
    // Setup exchange params
    let _busd = busd.address;
    let _usdc = usdc.address;
    let _usdt = usdt.address;
    let _clip = clip.address;
    await exchange.setRoute(
      [_busd, _busd, _usdc, _clip, _clip, _clip],
      [_usdt, _usdc, _usdt, _busd, _usdt, _usdc],
      [pancake, pancake, pancake, pancake, pancake, pancake]
    );

    // pancake plugin params
    await pancakePlugin.setUniswapRouter(uniswapRouter.address);
    // await pancakePlugin.setUseWeth(clip, busd, true);
    // await pancakePlugin.setUseWeth(clip, usdt, true);
    // await pancakePlugin.setUseWeth(clip, usdc, true);

    // const [owner, sender] = await ethers.getSigners();
    amountA = parseUnits(amount, await usdt.decimals());
    amountB = parseUnits(amount, await busd.decimals());

    await usdt.mint(sender.address, amountA);
    await busd.mint(sender.address, amountB);

    await usdt.connect(sender).approve(uniswapRouter.address, amountA);
    await busd.connect(sender).approve(uniswapRouter.address, amountB);

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

    // Setup exchange params
    await exchange.setRoute(
      [_busd, _busd, _usdc, clip, clip, clip],
      [_usdt, _usdc, _usdt, _busd, _usdt, _usdc],
      [pancake, pancake, pancake, pancake, pancake, pancake]
    );

    // pancake plugin params
    await pancakePlugin.setUniswapRouter(uniswapRouter);
    // await pancakePlugin.setUseWeth(clip, busd, true);
    // await pancakePlugin.setUseWeth(clip, usdt, true);
    // await pancakePlugin.setUseWeth(clip, usdc, true);
  }

  // Setup core params that are similar (or the same) as those that will be set in production
  // async function setupParamsOnBNB(router, oracle, exchange) {
  //   const [owner,,,,,,,,,,feeAddress] = await ethers.getSigners();
  //   // Setup router params
  //   await router.setMinUsdPerCycle(parseUniform("0.9"));
  //   await router.setFeesPercent(2000);
  //   await router.setFeesCollectionAddress(feeAddress.address);
  //   await router.setCycleDuration(1);

  //   await setupPluginsOnBNB(exchange);
  // }

  // async function setupPluginsOnBNB(exchange) {

  //   let clip = hre.networkVariables.clip;
  //   let busd = hre.networkVariables.busd;
  //   let usdt = hre.networkVariables.usdt;
  //   let usdc = hre.networkVariables.usdc;
  //   let acs4usd = hre.networkVariables.acs4usd.address;

  //   let acsPlugin = await deploy("CurvePlugin");
  //   let pancakePlugin = await deploy("UniswapPlugin");

  //   // Setup exchange params
  //   await exchange.setRoute(
  //     [busd, busd, usdc, clip, clip, clip],
  //     [usdt, usdc, usdt, busd, usdt, usdc],
  //     [acsPlugin.address, acsPlugin.address, acsPlugin.address,
  //       pancakePlugin.address, pancakePlugin.address, pancakePlugin.address]
  //   );

  //   // acs plugin params
  //   await acsPlugin.setCurvePool(busd, usdt, acs4usd);
  //   await acsPlugin.setCurvePool(usdc, usdt, acs4usd);
  //   await acsPlugin.setCurvePool(busd, usdc, acs4usd);
  //   await acsPlugin.setCoinIds(
  //     hre.networkVariables.acs4usd.address,
  //     hre.networkVariables.acs4usd.tokens,
  //     hre.networkVariables.acs4usd.coinIds
  //   );

  //   // pancake plugin params
  //   await pancakePlugin.setUniswapRouter(uniswapRouter);
  //   await pancakePlugin.setUseWeth(clip, busd, true);
  //   await pancakePlugin.setUseWeth(clip, usdt, true);
  //   await pancakePlugin.setUseWeth(clip, usdc, true);
  // }
});
