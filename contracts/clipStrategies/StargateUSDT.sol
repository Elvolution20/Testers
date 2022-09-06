//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;
import "../deps/openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../deps/uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "../deps/uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "../deps/uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/IStargateRouter.sol";
import "../interfaces/IClipSwapFarm.sol";

/** @title Stargate USDT Liquidity pool.
        How is works
        ------------
        - USDT Deposited into a single-sided liquidity pool on Stargate on the Binance Smart Chain
        - USDT Lp Token is staked in the USDT Liquidity Mining Farm.
        - Rewards are received as STG.
        - STG Tokens are sold out for USDT on PancakeSwap and deposited back into the pool.
    @notice: 
        params.clip : Contract of the reward token. (In this case STG)
        param.farm : Liquidity Mining Farm.

    @custom:oz-upgrades-unsafe-allow constructor state-variable-immutable
 */

contract StargateUSDT is Initializable, UUPSUpgradeable, OwnableUpgradeable, IStrategy {
    error CallerUpgrader();

    /**
        @notice Grouped state variables that require initialization in the constructor
                    Makes the code more cleaner and efficient working with parameters.
    */
    Parameters internal immutable params;

    uint256 private immutable LEFTOVER_THRESHOLD_TOKEN_A;
    uint256 private immutable LEFTOVER_THRESHOLD_TOKEN_B;
    uint256 private constant PERCENT_DENOMINATOR = 10000;

    modifier onlyUpgrader() {
        if (msg.sender != address(upgrader)) revert CallerUpgrader();
        _;
    }

    /**
        @dev constructor is intended to initialize immutables on implementation
            You could set _params.upgrader to address(0) i.e 0x0000000000000000000000000000000000000000
            Note: Parameters encapsulates all inputs most of which are of type contract since the incoming
                    addresses are unknown.
                Expected contents for _params
                -----------------------------
                o upgrader : Address permitted to upgrade this contract.
                o clip : STG contract Address.
                o farm : Farm contract.
                o stargateRouter : Router contract.
                o stategyRouter : StategyRouter contract.
                o poolId.
                o tokenA: Incoming USDT Token. 
                o lpToken: USDT LpToken.
    */
    constructor(Parameters memory _params) {
        params = _params;
        LEFTOVER_THRESHOLD_TOKEN_A = 10**_tokenA.decimals();
        LEFTOVER_THRESHOLD_TOKEN_B = 10**_tokenB.decimals();

        // lock implementation
        _disableInitializers();
    }

    function initialize(address _upgrader) external initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        params.upgrader = _upgrader;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyUpgrader {}

    /// @notice Returns deposited token  address i.e USDT in this case.
    function depositToken() external view override returns (address) {
        return address(params.tokenA);
    }

    /**
        @notice Deposits token into strategy.
            Callable only by the owner i.e StrategyRouter
     */
    function deposit(uint256 amount) external override onlyOwner {
        Parameters memory _p = params;
        Exchange exchange = _p.strategyRouter.getExchange();

        // uint256 dexFee = exchange.getFee(amount / 2, address(_p.tokenA), address(tokenB));
        // uint256 amountB = calculateSwapAmount(amount / 2, dexFee);
        // uint256 amountA = amount - amountB;

        _p.tokenA.transfer(address(exchange), amountB);
        // amountB = exchange.swap(amountB, address(_p.tokenA), address(_p.tokenB), address(this));

        _p.tokenA.approve(address(_p.clipRouter), amountA);
        // _p.tokenB.approve(address(_p.clipRouter), amountB);
        IStargateRouter(_p.stargateRouter).addLiquidity(_p.poolId, amount, address(address(this))); 

        _p.lpToken.approve(address(farm), amount);
        _p.farm.deposit(poolId, amount);
    }
    
    /**
        @dev Removes liquidity and withdraw LpToken
                Sells off token on the exchange
        @param strategyTokenAmountToWithdraw : Amount to withdraw
        @param destinationPoolid : The poolId on Stargate, where to send token.
     */
    function withdraw(
        uint256 strategyTokenAmountToWithdraw, 
        uint256 destinationPoolId, 
        uint lpAmountToRedeem,
        uint16 destinationChainId
    )
        external
        override
        onlyOwner
        returns (uint256 amountWithdrawn)
    {
        Parameters memory _p = params;
        address token0 = IUniswapV2Pair(address(_p.lpToken)).token0();
        address token1 = IUniswapV2Pair(address(_p.lpToken)).token1();
        // uint256 balance0 = IERC20(token0).balanceOf(address(_p.lpToken));
        uint256 balanceLp = IClipswapFarm(_p.farm).myStakedBalance();
        // uint256 amountA = strategyTokenAmountToWithdraw / 2;
        // uint256 amountB = strategyTokenAmountToWithdraw - amountA;

        // (balance0, balance1) = token0 == address(_p.tokenA) ? (balance0, balance1) : (balance1, balance0);

        // amountB = _p.clipRouter.quote(amountB, balance0, balance1);

        // uint256 liquidityToRemove = (_p.lpToken.totalSupply() * (amountA + amountB)) / (balance0 + balance1);

        IClipswapFarm(_p.farm).withdraw(_p.poolId, strategyTokenAmountToWithdraw);
        _p.lpToken.approve(address(_p.clipRouter), strategyTokenAmountToWithdraw);
        IStargateRouter(_p.stargateRouter).redeemLocal(
            _p.chainId, 
            _p.poolId, 
            destinationPoolId, 
            address(this), 
            lpAmountToRedeem, 
            abi.encode(address(this)), 
            lzTxObj(0, 0, "")
        );

        // Exchange exchange = strategyRouter.getExchange();
        // tokenB.transfer(address(exchange), amountB);
        // amountA += exchange.swap(amountB, address(tokenB), address(tokenA), address(this));
        tokenA.transfer(msg.sender, strategyTokenAmountToWithdraw);
        IStargateRouter(_p.strategyRouter).swap(
            _p.chainId, 
            _p.poolId, 
            destinationChainId, 
            payable(address(this)), 
            strategyTokenAmountToWithdraw, 
            strategyTokenAmountToWithdraw,
            IStargateRouter.lzTxObj(500000, 0, "0x"), 
            abi.encodePacked(address(this)), 
            ""
        );
        return strategyTokenAmountToWithdraw;
    }

    function compound() external override onlyOwner {
        // inside withdraw happens CLIP rewards collection
        _p.farm.withdraw(poolId, 0);
        // use balance because CLIP is harvested on deposit and withdraw calls
        uint256 clipAmount = _p.clip.balanceOf(address(this));

        if (clipAmount > 0) {
            fix_leftover(0);
            sellReward(clipAmount);
            uint256 balanceA = _p.tokenA.balanceOf(address(this));
            uint256 balanceB = _p.tokenB.balanceOf(address(this));

            tokenA.approve(address(_p.clipRouter), balanceA);
            tokenB.approve(address(_p.clipRouter), balanceB);

            _p.clipRouter.addLiquidity(
                address(_p.tokenA),
                address(_p.tokenB),
                balanceA,
                balanceB,
                0,
                0,
                address(this),
                block.timestamp
            );

            uint256 lpAmount = _p.lpToken.balanceOf(address(this));
            _p.lpToken.approve(_p.farm, lpAmount);
            IClipswapFarm(_p.farm).deposit(_p.poolId, lpAmount);
        }
    }

    // function totalTokens() external view override returns (uint256) {
    //     (uint256 liquidity, ) = IClipswapFarm(_p.farm).userInfo(_p.poolId, address(this));

    //     uint256 _totalSupply = _p.lpToken.totalSupply();
    //     // this formula is from uniswap.remove_liquidity -> uniswapPair.burn function
    //     uint256 balanceA = _p.tokenA.balanceOf(address(_p.lpToken));
    //     // uint256 balanceB = _p.tokenB.balanceOf(address(_p.lpToken));
    //     uint256 amountA = (liquidity * balanceA) / _totalSupply;
    //     uint256 amountB = (liquidity * balanceB) / _totalSupply;

    //     if (amountB > 0) {
    //         address token0 = IUniswapV2Pair(address(_p.lpToken)).token0();

    //         (uint256 _reserve0, uint256 _reserve1) = token0 == address(_p.tokenB)
    //             ? (balanceB, balanceA)
    //             : (balanceA, balanceB);

    //         // convert amountB to amount _p.tokenA
    //         amountA += _p.clipRouter.quote(amountB, _reserve0, _reserve1);
    //     }

    //     return amountA;
    // }

    function withdrawAll(uint256 destinationPoolId, uint lpAmountToRedeem) external override onlyOwner returns (uint256 amountWithdrawn) {
        Parameters memory _p = params;
        (uint256 amount, ) = _p.farm.userInfo(poolId, address(this));
        if (amount > 0) {
            _p.farm.withdraw(poolId, amount);
            uint256 lpAmount = _p.lpToken.balanceOf(address(this));
            _p.lpToken.approve(address(_p.clipRouter), lpAmount);
            IStargateRouter(_p.stargateRouter).redeemLocal(
                _p.chainId, 
                _p.poolId, 
                destinationPoolId, 
                msg.sender, 
                lpAmountToRedeem, 
                abi.encode(address(this)), 
                lzTxObj(0, 0, "")
            );
        }

        uint256 amountA = _p.tokenA.balanceOf(address(this));
        // uint256 amountB = _p.tokenB.balanceOf(address(this));

        // if (amountB > 0) {
        //     Exchange exchange = _p.strategyRouter.getExchange();
        //     _p.tokenB.transfer(address(exchange), amountB);
        //     amountA += exchange.swap(amountB, address(_p.tokenB), address(_p.tokenA), address(this));
        // }
        if (amountA > 0) {
            _p.tokenA.transfer(msg.sender, amountA);
            return amountA;
        }
    }

    // @dev Swaps leftover tokens for a better ratio for LP.
    function fix_leftover(uint256 amountIgnore) private {
        Exchange exchange = _p.strategyRouter.getExchange();
        uint256 amountB = _p.tokenB.balanceOf(address(this));
        uint256 amountA = _p.tokenA.balanceOf(address(this)) - amountIgnore;
        uint256 toSwap;
        if (amountB > amountA && (toSwap = amountB - amountA) > LEFTOVER_THRESHOLD_TOKEN_B) {
            uint256 dexFee = exchange.getFee(toSwap / 2, address(_p.tokenA), address(_p.tokenB));
            toSwap = calculateSwapAmount(toSwap / 2, dexFee);
            _p.tokenB.transfer(address(exchange), toSwap);
            exchange.swap(toSwap, address(_p.tokenB), address(_p.tokenA), address(this));
        } else if (amountA > amountB && (toSwap = amountA - amountB) > LEFTOVER_THRESHOLD_TOKEN_A) {
            uint256 dexFee = exchange.getFee(toSwap / 2, address(_p.tokenA), address(_p.tokenB));
            toSwap = calculateSwapAmount(toSwap / 2, dexFee);
            _p.tokenA.transfer(address(exchange), toSwap);
            exchange.swap(toSwap, address(_p.tokenA), address(_p.tokenB), address(this));
        }
    }

    // swap clip for _p.tokenA & _p.tokenB in proportions 50/50
    function sellReward(
        uint amountToSell,
        uint256 strategyTokenAmountToWithdraw, 
        uint256 destinationPoolId, 
        uint lpAmountToRedeem,
        uint16 destinationChainId
    ) public onlyOwner returns (uint256 receivedA, uint256 receivedB) {
        Parameters memory _p = params;
        // sell for lp ratio
        uint lpRewardBalance = _p.lpToken.balanceOf(address(this));
        if(lpRewardBalance > 0 && lpRewardBalance > amountToSell) {
            IStargateRouter(_p.strategyRouter).swap(
                _p.chainId, 
                _p.poolId, 
                destinationChainId, 
                payable(address(this)), 
                lpRewardBalance, 
                lpRewardBalance,
                IStargateRouter.lzTxObj(500000, 0, "0x"), 
                abi.encodePacked(msg.sender), 
                ""
            );
        }


        // uint256 amountA = clipAmount / 2;
        // uint256 amountB = clipAmount - amountA;

        // Exchange exchange = _p.strategyRouter.getExchange();
        // clip.transfer(address(exchange), amountA);
        // receivedA = exchange.swap(amountA, address(clip), address(_p.tokenA), address(this));

        // clip.transfer(address(exchange), amountB);
        // receivedB = exchange.swap(amountB, address(clip), address(_p.tokenB), address(this));

        // (receivedA, receivedB) = collectProtocolCommission(receivedA, receivedB);
    }

    // function collectProtocolCommission(uint256 amountA, uint256 amountB)
    //     private
    //     returns (uint256 amountAfterFeeA, uint256 amountAfterFeeB)
    // {
    //     uint256 feePercent = StrategyRouter(_p.strategyRouter).feePercent();
    //     address feeAddress = StrategyRouter(_p.strategyRouter).feeAddress();
    //     uint256 ratioUint;
    //     uint256 feeAmount = ((amountA + amountB) * feePercent) / PERCENT_DENOMINATOR;
    //     {
    //         (uint256 r0, uint256 r1, ) = IUniswapV2Pair(address(_p.lpToken)).getReserves();

    //         // equation: (a - (c*v))/(b - (c-c*v)) = z/x
    //         // solution for v = (a*x - b*z + c*z) / (c * (z+x))
    //         // a,b is current token amounts, z,x is pair reserves, c is total fee amount to take from a+b
    //         // v is ratio to apply to feeAmount and take fee from a and b
    //         // a and z should be converted to same decimals as token b (TODO for cases when decimals are different)
    //         int256 numerator = int256(amountA * r1 + feeAmount * r0) - int256(amountB * r0);
    //         int256 denominator = int256(feeAmount * (r0 + r1));
    //         int256 ratio = (numerator * 1e18) / denominator;
    //         // ratio here could be negative or greater than 1.0
    //         // only need to be between 0 and 1
    //         if (ratio < 0) ratio = 0;
    //         if (ratio > 1e18) ratio = 1e18;

    //         ratioUint = uint256(ratio);
    //     }

        // these two have same decimals, should adjust A to have A decimals,
        // this is TODO for cases when _p.tokenA and _p.tokenB has different decimals
    //     uint256 comissionA = (feeAmount * ratioUint) / 1e18;
    //     uint256 comissionB = feeAmount - comissionA;

    //     _p.tokenA.transfer(feeAddress, comissionA);
    //     _p.tokenB.transfer(feeAddress, comissionB);

    //     return (amountA - comissionA, amountB - comissionB);
    // }

    // function calculateSwapAmount(uint256 half, uint256 dexFee) private view returns (uint256 amountAfterFee) {
    //     (uint256 r0, uint256 r1, ) = IUniswapV2Pair(address(_p.lpToken)).getReserves();
    //     uint256 halfWithFee = (2 * r0 * (dexFee + 1e18)) / ((r0 * (dexFee + 1e18)) / 1e18 + r1);
    //     uint256 amountB = (half * halfWithFee) / 1e18;
    //     return amountB;
    // }
}




















































































// pragma solidity ^0.8.0;
// import "../deps/openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "../deps/uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
// import "../deps/uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
// import "../deps/uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
// import "../interfaces/IStrategy.sol";
// import "../interfaces/IClipswapFarm.sol";

// /** @title Stargate USDT Liquidity pool.
//         How is works
//         ------------
//         - USDT Deposited into a single-sided liquidity pool on Stargate on the Binance Smart Chain
//         - USDT Lp Token is staked in the USDT Liquidity Mining Farm.
//         - Rewards are received as STG.
//         - STG Tokens are sold out for USDT on PancakeSwap and deposited back into the pool.
//     @notice: 
//         params.clip : Contract of the reward token. (In this case STG)
//         param.farm : Liquidity Mining Farm.
        
//     @custom:oz-upgrades-unsafe-allow constructor state-variable-immutable
//  */
// contract USDTToSTG is Initializable, UUPSUpgradeable, OwnableUpgradeable, IStrategy {
//     error CallerUpgrader();

//     /**
//         @notice Grouped state variables that require initialization in the constructor
//                     Makes the code more cleaner and efficient working with parameters.
//     */
//     Parameters internal immutable params;

//     uint256 private immutable LEFTOVER_THRESHOLD_TOKEN_A;
//     uint256 private immutable LEFTOVER_THRESHOLD_TOKEN_B;
//     uint256 private constant PERCENT_DENOMINATOR = 10000;

//     modifier onlyUpgrader() {
//         if (msg.sender != address(upgrader)) revert CallerUpgrader();
//         _;
//     }

//     /**
//         @dev constructor is intended to initialize immutables on implementation
//             You could set _params.upgrader to address(0) i.e 0x0000000000000000000000000000000000000000
//             Note: Parameters encapsulates all inputs most of which are of type contract since the incoming
//                     addresses are unknown.
//                 Expected contents for _params
//                 -----------------------------
//                 o upgrader : Address permitted to upgrade this contract.
//                 o clip : Address of the native token to earn.
//                 o farm : Farm contract.
//                 o clipRouter : Router contract.
//                 o stategyRouter : StategyRouter contract.
//                 o poolId.
//                 o tokenA.
//                 o tokenB.
//                 o lpToken.
//     */
//     constructor(Parameters memory _params) {
//         params = _params;
//         LEFTOVER_THRESHOLD_TOKEN_A = 10**_tokenA.decimals();
//         LEFTOVER_THRESHOLD_TOKEN_B = 10**_tokenB.decimals();

//         // lock implementation
//         _disableInitializers();
//     }

//     function initialize(address _upgrader) external initializer {
//         __Ownable_init();
//         __UUPSUpgradeable_init();
//         params.upgrader = _upgrader;
//     }

//     function _authorizeUpgrade(address newImplementation) internal override onlyUpgrader {}

//     function depositToken() external view override returns (address) {
//         return address(params.tokenA);
//     }

//     function deposit(uint256 amount) external override onlyOwner {
//         Parameters memory _p = params;
//         Exchange exchange = _p.strategyRouter.getExchange();

//         uint256 dexFee = exchange.getFee(amount / 2, address(_p.tokenA), address(tokenB));
//         uint256 amountB = calculateSwapAmount(amount / 2, dexFee);
//         uint256 amountA = amount - amountB;

//         _p.tokenA.transfer(address(exchange), amountB);
//         amountB = exchange.swap(amountB, address(_p.tokenA), address(_p.tokenB), address(this));

//         _p.tokenA.approve(address(_p.clipRouter), amountA);
//         _p.tokenB.approve(address(_p.clipRouter), amountB);
//         (, , uint256 liquidity) = _p.clipRouter.addLiquidity(
//             address(_p.tokenA),
//             address(_p.tokenB),
//             amountA,
//             amountB,
//             0,
//             0,
//             address(this),
//             block.timestamp
//         );

//         _p.lpToken.approve(address(farm), liquidity);
//         _p.farm.deposit(poolId, liquidity);
//     }
    
//     /**
//         @dev Removes liquidity and withdraw LpToken
//                 Sells off token on the exchange
//      */
//     function withdraw(uint256 strategyTokenAmountToWithdraw)
//         external
//         override
//         onlyOwner
//         returns (uint256 amountWithdrawn)
//     {
//         address token0 = IUniswapV2Pair(address(_p.lpToken)).token0();
//         address token1 = IUniswapV2Pair(address(_p.lpToken)).token1();
//         uint256 balance0 = IERC20(token0).balanceOf(address(_p.lpToken));
//         uint256 balance1 = IERC20(token1).balanceOf(address(_p.lpToken));

//         uint256 amountA = strategyTokenAmountToWithdraw / 2;
//         uint256 amountB = strategyTokenAmountToWithdraw - amountA;

//         (balance0, balance1) = token0 == address(_p.tokenA) ? (balance0, balance1) : (balance1, balance0);

//         amountB = _p.clipRouter.quote(amountB, balance0, balance1);

//         uint256 liquidityToRemove = (_p.lpToken.totalSupply() * (amountA + amountB)) / (balance0 + balance1);

//         _p.farm.withdraw(_p.poolId, liquidityToRemove);
//         _p.lpToken.approve(address(_p.clipRouter), liquidityToRemove);
//         (amountA, amountB) = _p.clipRouter.removeLiquidity(
//             address(_p.tokenA),
//             address(_p.tokenB),
//             _p.lpToken.balanceOf(address(this)),
//             0,
//             0,
//             address(this),
//             block.timestamp
//         );

//         Exchange exchange = strategyRouter.getExchange();
//         tokenB.transfer(address(exchange), amountB);
//         amountA += exchange.swap(amountB, address(tokenB), address(tokenA), address(this));
//         tokenA.transfer(msg.sender, amountA);
//         return amountA;
//     }

//     function compound() external override onlyOwner {
//         // inside withdraw happens CLIP rewards collection
//         _p.farm.withdraw(poolId, 0);
//         // use balance because CLIP is harvested on deposit and withdraw calls
//         uint256 clipAmount = _p.clip.balanceOf(address(this));

//         if (clipAmount > 0) {
//             fix_leftover(0);
//             sellReward(clipAmount);
//             uint256 balanceA = _p.tokenA.balanceOf(address(this));
//             uint256 balanceB = _p.tokenB.balanceOf(address(this));

//             tokenA.approve(address(_p.clipRouter), balanceA);
//             tokenB.approve(address(_p.clipRouter), balanceB);

//             _p.clipRouter.addLiquidity(
//                 address(_p.tokenA),
//                 address(_p.tokenB),
//                 balanceA,
//                 balanceB,
//                 0,
//                 0,
//                 address(this),
//                 block.timestamp
//             );

//             uint256 lpAmount = _p.lpToken.balanceOf(address(this));
//             _p.lpToken.approve(address(_p.farm), lpAmount);
//             _p.farm.deposit(_p.poolId, lpAmount);
//         }
//     }

//     function totalTokens() external view override returns (uint256) {
//         (uint256 liquidity, ) = _p.farm.userInfo(_p.poolId, address(this));

//         uint256 _totalSupply = _p.lpToken.totalSupply();
//         // this formula is from uniswap.remove_liquidity -> uniswapPair.burn function
//         uint256 balanceA = _p.tokenA.balanceOf(address(_p.lpToken));
//         uint256 balanceB = _p.tokenB.balanceOf(address(_p.lpToken));
//         uint256 amountA = (liquidity * balanceA) / _totalSupply;
//         uint256 amountB = (liquidity * balanceB) / _totalSupply;

//         if (amountB > 0) {
//             address token0 = IUniswapV2Pair(address(_p.lpToken)).token0();

//             (uint256 _reserve0, uint256 _reserve1) = token0 == address(_p.tokenB)
//                 ? (balanceB, balanceA)
//                 : (balanceA, balanceB);

//             // convert amountB to amount _p.tokenA
//             amountA += _p.clipRouter.quote(amountB, _reserve0, _reserve1);
//         }

//         return amountA;
//     }

//     function withdrawAll() external override onlyOwner returns (uint256 amountWithdrawn) {
//         (uint256 amount, ) = _p.farm.userInfo(poolId, address(this));
//         if (amount > 0) {
//             _p.farm.withdraw(poolId, amount);
//             uint256 lpAmount = _p.lpToken.balanceOf(address(this));
//             _p.lpToken.approve(address(_p.clipRouter), lpAmount);
//             _p.clipRouter.removeLiquidity(
//                 address(_p.tokenA),
//                 address(_p.tokenB),
//                 _p.lpToken.balanceOf(address(this)),
//                 0,
//                 0,
//                 address(this),
//                 block.timestamp
//             );
//         }

//         uint256 amountA = _p.tokenA.balanceOf(address(this));
//         uint256 amountB = _p.tokenB.balanceOf(address(this));

//         if (amountB > 0) {
//             Exchange exchange = _p.strategyRouter.getExchange();
//             _p.tokenB.transfer(address(exchange), amountB);
//             amountA += exchange.swap(amountB, address(_p.tokenB), address(_p.tokenA), address(this));
//         }
//         if (amountA > 0) {
//             _p.tokenA.transfer(msg.sender, amountA);
//             return amountA;
//         }
//     }

//     /// @dev Swaps leftover tokens for a better ratio for LP.
//     function fix_leftover(uint256 amountIgnore) private {
//         Exchange exchange = _p.strategyRouter.getExchange();
//         uint256 amountB = _p.tokenB.balanceOf(address(this));
//         uint256 amountA = _p.tokenA.balanceOf(address(this)) - amountIgnore;
//         uint256 toSwap;
//         if (amountB > amountA && (toSwap = amountB - amountA) > LEFTOVER_THRESHOLD_TOKEN_B) {
//             uint256 dexFee = exchange.getFee(toSwap / 2, address(_p.tokenA), address(_p.tokenB));
//             toSwap = calculateSwapAmount(toSwap / 2, dexFee);
//             _p.tokenB.transfer(address(exchange), toSwap);
//             exchange.swap(toSwap, address(_p.tokenB), address(_p.tokenA), address(this));
//         } else if (amountA > amountB && (toSwap = amountA - amountB) > LEFTOVER_THRESHOLD_TOKEN_A) {
//             uint256 dexFee = exchange.getFee(toSwap / 2, address(_p.tokenA), address(_p.tokenB));
//             toSwap = calculateSwapAmount(toSwap / 2, dexFee);
//             _p.tokenA.transfer(address(exchange), toSwap);
//             exchange.swap(toSwap, address(_p.tokenA), address(_p.tokenB), address(this));
//         }
//     }

//     // swap clip for _p.tokenA & _p.tokenB in proportions 50/50
//     function sellReward(uint256 clipAmount) private returns (uint256 receivedA, uint256 receivedB) {
//         // sell for lp ratio
//         uint256 amountA = clipAmount / 2;
//         uint256 amountB = clipAmount - amountA;

//         Exchange exchange = _p.strategyRouter.getExchange();
//         clip.transfer(address(exchange), amountA);
//         receivedA = exchange.swap(amountA, address(clip), address(_p.tokenA), address(this));

//         clip.transfer(address(exchange), amountB);
//         receivedB = exchange.swap(amountB, address(clip), address(_p.tokenB), address(this));

//         (receivedA, receivedB) = collectProtocolCommission(receivedA, receivedB);
//     }

//     function collectProtocolCommission(uint256 amountA, uint256 amountB)
//         private
//         returns (uint256 amountAfterFeeA, uint256 amountAfterFeeB)
//     {
//         uint256 feePercent = StrategyRouter(_p.strategyRouter).feePercent();
//         address feeAddress = StrategyRouter(_p.strategyRouter).feeAddress();
//         uint256 ratioUint;
//         uint256 feeAmount = ((amountA + amountB) * feePercent) / PERCENT_DENOMINATOR;
//         {
//             (uint256 r0, uint256 r1, ) = IUniswapV2Pair(address(_p.lpToken)).getReserves();

//             // equation: (a - (c*v))/(b - (c-c*v)) = z/x
//             // solution for v = (a*x - b*z + c*z) / (c * (z+x))
//             // a,b is current token amounts, z,x is pair reserves, c is total fee amount to take from a+b
//             // v is ratio to apply to feeAmount and take fee from a and b
//             // a and z should be converted to same decimals as token b (TODO for cases when decimals are different)
//             int256 numerator = int256(amountA * r1 + feeAmount * r0) - int256(amountB * r0);
//             int256 denominator = int256(feeAmount * (r0 + r1));
//             int256 ratio = (numerator * 1e18) / denominator;
//             // ratio here could be negative or greater than 1.0
//             // only need to be between 0 and 1
//             if (ratio < 0) ratio = 0;
//             if (ratio > 1e18) ratio = 1e18;

//             ratioUint = uint256(ratio);
//         }

//         // these two have same decimals, should adjust A to have A decimals,
//         // this is TODO for cases when _p.tokenA and _p.tokenB has different decimals
//         uint256 comissionA = (feeAmount * ratioUint) / 1e18;
//         uint256 comissionB = feeAmount - comissionA;

//         _p.tokenA.transfer(feeAddress, comissionA);
//         _p.tokenB.transfer(feeAddress, comissionB);

//         return (amountA - comissionA, amountB - comissionB);
//     }

//     function calculateSwapAmount(uint256 half, uint256 dexFee) private view returns (uint256 amountAfterFee) {
//         (uint256 r0, uint256 r1, ) = IUniswapV2Pair(address(_p.lpToken)).getReserves();
//         uint256 halfWithFee = (2 * r0 * (dexFee + 1e18)) / ((r0 * (dexFee + 1e18)) / 1e18 + r1);
//         uint256 amountB = (half * halfWithFee) / 1e18;
//         return amountB;
//     }
// }

