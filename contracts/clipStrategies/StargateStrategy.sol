//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/IStargateRouter.sol";
import "../interfaces/IClipSwapFarm.sol";
// import "../StrategyRouter.sol";

/** Stargate USDT Liquidity pool.
        How is works
        ------------
        - USDT Deposited into a single-sided liquidity pool on Stargate on the Binance Smart Chain
        - USDT Lp Token is staked in the USDT Liquidity Mining Farm.
        - Rewards are received as STG.
        - STG Tokens are sold out for USDT on PancakeSwap and deposited back into the pool.

        stg : Contract of the reward token. (In this case STG)
        farm : Liquidity Mining Farm.
    
    Functions: 
        o deposit()
        o withdraw()
        o withdrawall()
        o compound()

    @custom:oz-upgrades-unsafe-allow constructor state-variable-immutable
 */

contract StargateStrategy is Initializable, UUPSUpgradeable, OwnableUpgradeable, IStrategy {
    error CallerUpgrader();

    address internal upgrader;
    
    ERC20 internal tokenA;
    // ERC20 internal stgRewardToken;
    ERC20 internal lpToken;
    StrategyRouter internal strategyRouter;

    address internal stargateRouter;

    ERC20 internal stgRewardToken;
    IClipSwapFarm internal farm;
    IUniswapV2Router02 internal stgRouter;

    uint256 internal poolId;

    uint256 private LEFTOVER_THRESHOLD_TOKEN_A;
    uint256 private LEFTOVER_THRESHOLD_TOKEN_B;
    uint256 private constant PERCENT_DENOMINATOR = 10000;

    modifier onlyUpgrader() {
        if (msg.sender != address(upgrader)) revert CallerUpgrader();
        _;
    }

    /// @dev construct is intended to initialize immutables on implementation
    constructor() {
        // lock implementation
        _disableInitializers();
    }

    function initialize(
        address _upgrader,
        StrategyRouter _strategyRouter,
        uint256 _poolId,
        ERC20 _tokenA,
        ERC20 _lpToken,
        ERC20 _stgRewardToken,
        address _farm,
        address _stgRouter,
        address _stargateRouter
    ) external initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        upgrader = _upgrader;
         strategyRouter = _strategyRouter;
        poolId = _poolId;
        tokenA = _tokenA;
        lpToken = _lpToken;
        stgRewardToken = _stgRewardToken ;
        farm = IClipSwapFarm(_farm);
        stgRouter = IUniswapV2Router02(_stgRouter);
        stargateRouter = _stargateRouter;
        LEFTOVER_THRESHOLD_TOKEN_A = 10**_tokenA.decimals();
        LEFTOVER_THRESHOLD_TOKEN_B = 10**_stgRewardToken.decimals();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyUpgrader {}

    function depositToken() external view override returns (address) {
        return address(tokenA);
    }

    function deposit(uint256 amount) external override onlyOwner {
        // Exchange exchange = strategyRouter.getExchange();
        tokenA.approve(address(stargateRouter), amount);
        IStargateRouter(stargateRouter).addLiquidity(poolId, amount, address(address(this))); 
        stgRewardToken.approve(address(farm), amount);
        farm.deposit(poolId, amount);
    }

    function withdraw(uint256 amtToWithdraw)
        external
        override
        onlyOwner
        returns (uint256 amountWithdrawn)
    {
        IClipSwapFarm(farm).withdraw(poolId, amtToWithdraw);
        uint256 balance1 = stgRewardToken.balanceOf(address(this));
        // stgRewardToken.approve(address(stgRouter), amtToWithdraw);
        IStargateRouter(stargateRouter).redeemLocal(
            97, //testnet 
            poolId, 
            97, // BSC testnet
            payable(address(this)), 
            balance1, 
            abi.encode(address(this)), 
            IStargateRouter.lzTxObj(0, 0, "")
        );
        lpToken.approve(address(stgRouter), amtToWithdraw);

        Exchange exchange = strategyRouter.getExchange();
        stgRewardToken.approve(address(exchange), balance1);
        uint amountA = exchange.swap(balance1, address(stgRewardToken), address(tokenA), address(this));
        tokenA.transfer(msg.sender, amountA);
       
        return amountA;
    }

    function compound() external override onlyOwner {
        // inside withdraw happens STG rewards collection
        farm.withdraw(poolId, 0);
        // use balance because STG is harvested on deposit and withdraw calls
        uint256 stgAmount = stgRewardToken.balanceOf(address(this));

        if (stgAmount > 0) {
            fix_leftover(0);
            sellReward(stgAmount);
            uint256 balanceA = tokenA.balanceOf(address(this));
            uint256 balanceB = stgRewardToken.balanceOf(address(this));

            tokenA.approve(address(stargateRouter), balanceA);
            stgRewardToken.approve(address(stgRouter), balanceB);
            IStargateRouter(stargateRouter).addLiquidity(poolId, balanceA, address(this));

            uint256 lpAmount = lpToken.balanceOf(address(this));
            lpToken.approve(address(farm), lpAmount);
            farm.deposit(poolId, lpAmount);
        }
    }


    function withdrawAll() external override onlyOwner returns (uint256 amountWithdrawn) {
        (uint256 amount, ) = farm.userInfo(poolId, address(this));
        if (amount > 0) {
            farm.withdraw(poolId, amount);
            uint256 lpAmount = lpToken.balanceOf(address(this));
            lpToken.approve(address(stgRouter), lpAmount);
            IStargateRouter(stargateRouter).redeemLocal(
                97, //Testnet 
                poolId, 
                poolId, 
                payable(address(this)), 
                lpAmount, 
                abi.encode(address(this)), 
                IStargateRouter.lzTxObj(0, 0, "")
            );
        }

        uint256 amountA = tokenA.balanceOf(address(this));
        uint256 amountB = stgRewardToken.balanceOf(address(this));

        if (amountB > 0) {
            Exchange exchange = strategyRouter.getExchange();
            stgRewardToken.transfer(address(exchange), amountB);
            amountA += exchange.swap(amountB, address(stgRewardToken), address(tokenA), address(this));
        }
        if (amountA > 0) {
            tokenA.transfer(msg.sender, amountA);
            return amountA;
        }
    }

    function totalTokens() external view override returns (uint256) {
        (uint256 liquidity, ) = farm.userInfo(poolId, address(this));

        uint256 _totalSupply = lpToken.totalSupply();
        // this formula is from uniswap.remove_liquidity -> uniswapPair.burn function
        uint256 balanceA = tokenA.balanceOf(address(lpToken));
        uint256 balanceB = stgRewardToken.balanceOf(address(lpToken));
        uint256 amountA = (liquidity * balanceA) / _totalSupply;
        uint256 amountB = (liquidity * balanceB) / _totalSupply;

        if (amountB > 0) {
            address token0 = IUniswapV2Pair(address(lpToken)).token0();

            (uint256 _reserve0, uint256 _reserve1) = token0 == address(stgRewardToken)
                ? (balanceB, balanceA)
                : (balanceA, balanceB);

            // convert amountB to amount tokenA
            amountA += stgRouter.quote(amountB, _reserve0, _reserve1);
        }

        return amountA;
    }


    /// @dev Swaps leftover tokens for a better ratio for LP.
    function fix_leftover(uint256 amountIgnore) private {
        Exchange exchange = strategyRouter.getExchange();
        uint256 amountB = stgRewardToken.balanceOf(address(this));
        uint256 amountA = tokenA.balanceOf(address(this)) - amountIgnore;
        uint256 toSwap;
        if (amountB > amountA && (toSwap = amountB - amountA) > LEFTOVER_THRESHOLD_TOKEN_B) {
            uint256 dexFee = exchange.getFee(toSwap / 2, address(tokenA), address(stgRewardToken));
            toSwap = calculateSwapAmount(toSwap / 2, dexFee);
            stgRewardToken.transfer(address(exchange), toSwap);
            exchange.swap(toSwap, address(stgRewardToken), address(tokenA), address(this));
        } else if (amountA > amountB && (toSwap = amountA - amountB) > LEFTOVER_THRESHOLD_TOKEN_A) {
            uint256 dexFee = exchange.getFee(toSwap / 2, address(tokenA), address(stgRewardToken));
            toSwap = calculateSwapAmount(toSwap / 2, dexFee);
            tokenA.transfer(address(exchange), toSwap);
            exchange.swap(toSwap, address(tokenA), address(stgRewardToken), address(this));
        }
    }

    // swap stgRewardToken for tokenA & stgRewardToken in proportions 50/50
    function sellReward(uint256 stgRewardTokenAmount) private returns (uint256 receivedA, uint256 receivedB) {
        // sell for lp ratio
        uint256 amountA = stgRewardTokenAmount / 2;
        uint256 amountB = stgRewardTokenAmount - amountA;

        Exchange exchange = strategyRouter.getExchange();
        stgRewardToken.transfer(address(exchange), amountA);
        receivedA = exchange.swap(amountA, address(stgRewardToken), address(tokenA), address(this));

        stgRewardToken.transfer(address(exchange), amountB);
        receivedB = exchange.swap(amountB, address(stgRewardToken), address(stgRewardToken), address(this));

        (receivedA, receivedB) = collectProtocolCommission(receivedA, receivedB);
    }

    function collectProtocolCommission(uint256 amountA, uint256 amountB)
        private
        returns (uint256 amountAfterFeeA, uint256 amountAfterFeeB)
    {
        uint256 feePercent = StrategyRouter(strategyRouter).feePercent();
        address feeAddress = StrategyRouter(strategyRouter).feeAddress();
        uint256 ratioUint;
        uint256 feeAmount = ((amountA + amountB) * feePercent) / PERCENT_DENOMINATOR;
        {
            (uint256 r0, uint256 r1, ) = IUniswapV2Pair(address(lpToken)).getReserves();

            // equation: (a - (c*v))/(b - (c-c*v)) = z/x
            // solution for v = (a*x - b*z + c*z) / (c * (z+x))
            // a,b is current token amounts, z,x is pair reserves, c is total fee amount to take from a+b
            // v is ratio to apply to feeAmount and take fee from a and b
            // a and z should be converted to same decimals as token b (TODO for cases when decimals are different)
            int256 numerator = int256(amountA * r1 + feeAmount * r0) - int256(amountB * r0);
            int256 denominator = int256(feeAmount * (r0 + r1));
            int256 ratio = (numerator * 1e18) / denominator;
            // ratio here could be negative or greater than 1.0
            // only need to be between 0 and 1
            if (ratio < 0) ratio = 0;
            if (ratio > 1e18) ratio = 1e18;

            ratioUint = uint256(ratio);
        }

        // these two have same decimals, should adjust A to have A decimals,
        // this is TODO for cases when tokenA and stgRewardToken has different decimals
        uint256 comissionA = (feeAmount * ratioUint) / 1e18;
        // uint256 comissionB = feeAmount - comissionA;

        tokenA.transfer(feeAddress, comissionA);
        // stgRewardToken.transfer(feeAddress, comissionB);

        return (amountA - comissionA, 0);
    }

    function calculateSwapAmount(uint256 half, uint256 dexFee) private view returns (uint256 amountAfterFee) {
        (uint256 r0, uint256 r1, ) = IUniswapV2Pair(address(stgRewardToken)).getReserves();
        uint256 halfWithFee = (2 * r0 * (dexFee + 1e18)) / ((r0 * (dexFee + 1e18)) / 1e18 + r1);
        uint256 amountB = (half * halfWithFee) / 1e18;
        return amountB;
    }
}