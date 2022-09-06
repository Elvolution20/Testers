//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "../deps/openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../main/StrategyRouter.sol";
import "./ClipswapBase.sol";

// import "hardhat/console.sol";

/// @custom:oz-upgrades-unsafe-allow constructor state-variable-immutable
contract ClipSwapUSDTForUSDT
 is BiswapBase {
    constructor(StrategyRouter _strategyRouter, address usdtLpToken, address tokenA, address tokenB)
        ClipswapBase(
            _strategyRouter,
            1, // poolId
            ERC20(tokenA), // tokenA
            ERC20(tokenB), // tokenB
            ERC20(usdtLpToken) // lpToken
        )
    {}
}
