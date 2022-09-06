//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

// import "../StrategyRouter.sol";
import "../deps/openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../deps/uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol"
import "../interfaces/IClipswapFarm.sol";
import "../interfaces/IStargate.sol";

interface Parameters {
  struct Param1 {
    address upgrader;
    address farm;
    IStargate stargateRouter;
    address strategyRouter;
    uint256 poolId;
    uint24 chainId;
    ERC20 tokenA;
    // ERC20 tokenB;
    ERC20 lpToken;
    address clip;
  }
}