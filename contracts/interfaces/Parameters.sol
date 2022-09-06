//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "../StrategyRouter.sol";
import "../deps/openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../deps/uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol"
import "../interfaces/IClipswapFarm.sol";

interface Parameters {
  struct Param1 {
    address upgrader;
    IClipswapFarm farm;
    IUniswapV2Router02 clipswapRouter;
    StrategyRouter strategyRouter;
    uint256 poolId;
    ERC20 tokenA;
    ERC20 tokenB;
    ERC20 lpToken;
    ERC20 clip;
  }
}