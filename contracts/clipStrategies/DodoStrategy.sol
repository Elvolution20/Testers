//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "../interfaces/IClipSwapFarm.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/IDodoStrategy.sol";
import "../main/StrategyRouter.sol";

/** Dodo Exchange USDT Liquidity pool.
        How is works
        ------------
        - USDT is converted to an LP token in the BUSD-USDT Pool on the DODO Exchange
        - USDT LP token is staked in the BUSD-USDT liquidity mining farm.
        - Rewards are received as DODO tokens.
        - DODO tokens are sold for USDT and deposited back into the pool.
           
        Functions: 
            o deposit()
            o withdraw()
            o withdrawall()
            o compound()

        params.clip : Contract of the reward token. (In this case Dodo)
        param.farm : Liquidity Mining Farm.

    @custom:oz-upgrades-unsafe-allow constructor state-variable-immutable
 */

contract DodoStrategy is Ownable, IStrategy {
    // error CallerUpgrader();

    // address internal upgrader;
    
    ERC20 internal tokenA; // USDT Token to deposit
    ERC20 internal tokenB; // BUSD 
    ERC20 internal lpToken; // BUSD-USDT LpToken
    StrategyRouter internal strategyRouter; // StrategyRouter contract

    ERC20 internal constant dodo = ERC20(0x67ee3Cb086F8a16f34beE3ca72FAD36F7Db929e2); //reward token
    IClipSwapFarm internal farm; // Dodo farm
    IUniswapV2Router02 internal dodoRouter;  // Dodo Exchange

    uint256 internal poolId;

    uint256 private LEFTOVER_THRESHOLD_TOKEN_A;
    uint256 private LEFTOVER_THRESHOLD_TOKEN_B;
    uint256 private constant PERCENT_DENOMINATOR = 10000;

    // modifier onlyUpgrader() {
    //     if (msg.sender != address(upgrader)) revert CallerUpgrader();
    //     _;
    // }

    /// @dev construct is intended to initialize immutables on implementation
    constructor() {
        // lock implementation
        // _disableInitializers();
    }

    function initializeState(
        // address _upgrader,
        StrategyRouter _strategyRouter,
        uint256 _poolId,
        ERC20 _tokenA,
        ERC20 _tokenB,
        ERC20 _lpToken,
        address _farm,
        address _dodoRouter
    ) external onlyOwner {
        // __Ownable_init();
        // __UUPSUpgradeable_init();
        // upgrader = _upgrader;
        strategyRouter = _strategyRouter;
        poolId = _poolId;
        tokenA = _tokenA;
        tokenB = _tokenB;
        lpToken = _lpToken;
        farm = IClipSwapFarm(_farm);
        dodoRouter = IUniswapV2Router02(_dodoRouter);
        LEFTOVER_THRESHOLD_TOKEN_A = 10**_tokenA.decimals();
        LEFTOVER_THRESHOLD_TOKEN_B = 10**_tokenB.decimals();
    }

    // function _authorizeUpgrade(address newImplementation) internal override onlyUpgrader {}

    function depositToken() external view override returns (address) {
        return address(tokenA);
    }

    function deposit(uint256 amount) external override onlyOwner {
        Exchange exchange = strategyRouter.getExchange();

        // uint256 dexFee = exchange.getFee(amount / 2, address(tokenA), address(tokenB));
        uint256 amountB = calculateSwapAmount(amount / 2, 0);
        // uint256 amountB = calculateSwapAmount(amount / 2);
        uint256 amountA = amount - amountB;

        tokenA.transfer(address(exchange), amountB);
        amountB = exchange.swap(amountB, address(tokenA), address(tokenB), address(this));

        tokenA.approve(address(dodoRouter), amountA);
        tokenB.approve(address(dodoRouter), amountB);
        (, , uint256 liquidity) = dodoRouter.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA,
            amountB,
            0,
            0,
            address(this),
            block.timestamp
        );

        lpToken.approve(address(farm), liquidity);
        farm.deposit(poolId, liquidity);
    }

    function withdraw(uint256 strategyTokenAmountToWithdraw)
        external
        override
        onlyOwner
        returns (uint256 amountWithdrawn)
    {
        address token0 = IUniswapV2Pair(address(lpToken)).token0();
        address token1 = IUniswapV2Pair(address(lpToken)).token1();
        uint256 balance0 = IERC20(token0).balanceOf(address(lpToken));
        uint256 balance1 = IERC20(token1).balanceOf(address(lpToken));

        uint256 amountA = strategyTokenAmountToWithdraw / 2;
        uint256 amountB = strategyTokenAmountToWithdraw - amountA;

        (balance0, balance1) = token0 == address(tokenA) ? (balance0, balance1) : (balance1, balance0);

        amountB = dodoRouter.quote(amountB, balance0, balance1);

        uint256 liquidityToRemove = (lpToken.totalSupply() * (amountA + amountB)) / (balance0 + balance1);

        farm.withdraw(poolId, liquidityToRemove);
        lpToken.approve(address(dodoRouter), liquidityToRemove);
        (amountA, amountB) = dodoRouter.removeLiquidity(
            address(tokenA),
            address(tokenB),
            lpToken.balanceOf(address(this)),
            0,
            0,
            address(this),
            block.timestamp
        );

        Exchange exchange = strategyRouter.getExchange();
        tokenB.approve(address(exchange), amountB);
        amountA += exchange.swap(amountB, address(tokenB), address(tokenA), address(this));
        tokenA.transfer(msg.sender, amountA);
        return amountA;
    }

    function compound() external override onlyOwner {
        // inside withdraw happens DODO rewards collection
        farm.withdraw(poolId, 0);
        // use balance because DODO is harvested on deposit and withdraw calls
        uint256 dodoAmount = dodo.balanceOf(address(this));

        if (dodoAmount > 0) {
            fix_leftover(0);
            sellReward(dodoAmount);
            uint256 balanceA = tokenA.balanceOf(address(this));
            uint256 balanceB = tokenB.balanceOf(address(this));

            tokenA.approve(address(dodoRouter), balanceA);
            tokenB.approve(address(dodoRouter), balanceB);

            dodoRouter.addLiquidity(
                address(tokenA),
                address(tokenB),
                balanceA,
                balanceB,
                0,
                0,
                address(this),
                block.timestamp
            );

            uint256 lpAmount = lpToken.balanceOf(address(this));
            lpToken.approve(address(farm), lpAmount);
            farm.deposit(poolId, lpAmount);
        }
    }

    function totalTokens() external view override returns (uint256) {
        (uint256 liquidity, ) = farm.userInfo(poolId, address(this));

        uint256 _totalSupply = lpToken.totalSupply();
        // this formula is from uniswap.remove_liquidity -> uniswapPair.burn function
        uint256 balanceA = tokenA.balanceOf(address(lpToken));
        uint256 balanceB = tokenB.balanceOf(address(lpToken));
        uint256 amountA = (liquidity * balanceA) / _totalSupply;
        uint256 amountB = (liquidity * balanceB) / _totalSupply;

        if (amountB > 0) {
            address token0 = IUniswapV2Pair(address(lpToken)).token0();

            (uint256 _reserve0, uint256 _reserve1) = token0 == address(tokenB)
                ? (balanceB, balanceA)
                : (balanceA, balanceB);

            // convert amountB to amount tokenA
            amountA += dodoRouter.quote(amountB, _reserve0, _reserve1);
        }

        return amountA;
    }

    function withdrawAll() external override onlyOwner returns (uint256 amountWithdrawn) {
        (uint256 amount, ) = farm.userInfo(poolId, address(this));
        if (amount > 0) {
            farm.withdraw(poolId, amount);
            uint256 lpAmount = lpToken.balanceOf(address(this));
            lpToken.approve(address(dodoRouter), lpAmount);
            dodoRouter.removeLiquidity(
                address(tokenA),
                address(tokenB),
                lpToken.balanceOf(address(this)),
                0,
                0,
                address(this),
                block.timestamp
            );
        }

        uint256 amountA = tokenA.balanceOf(address(this));
        uint256 amountB = tokenB.balanceOf(address(this));

        if (amountB > 0) {
            Exchange exchange = strategyRouter.getExchange();
            tokenB.transfer(address(exchange), amountB);
            amountA += exchange.swap(amountB, address(tokenB), address(tokenA), address(this));
        }
        if (amountA > 0) {
            tokenA.transfer(msg.sender, amountA);
            return amountA;
        }
    }

    /// @dev Swaps leftover tokens for a better ratio for LP.
    function fix_leftover(uint256 amountIgnore) private {
        Exchange exchange = strategyRouter.getExchange();
        uint256 amountB = tokenB.balanceOf(address(this));
        uint256 amountA = tokenA.balanceOf(address(this)) - amountIgnore;
        uint256 toSwap;
        if (amountB > amountA && (toSwap = amountB - amountA) > LEFTOVER_THRESHOLD_TOKEN_B) {
            uint256 dexFee = exchange.getFee(toSwap / 2, address(tokenA), address(tokenB));
            toSwap = calculateSwapAmount(toSwap / 2, dexFee);
            tokenB.transfer(address(exchange), toSwap);
            exchange.swap(toSwap, address(tokenB), address(tokenA), address(this));
        } else if (amountA > amountB && (toSwap = amountA - amountB) > LEFTOVER_THRESHOLD_TOKEN_A) {
            uint256 dexFee = exchange.getFee(toSwap / 2, address(tokenA), address(tokenB));
            toSwap = calculateSwapAmount(toSwap / 2, dexFee);
            tokenA.transfer(address(exchange), toSwap);
            exchange.swap(toSwap, address(tokenA), address(tokenB), address(this));
        }
    }

    // swap dodo for tokenA & tokenB in proportions 50/50
    function sellReward(uint256 dodoAmount) private returns (uint256 receivedA, uint256 receivedB) {
        // sell for lp ratio
        uint256 amountA = dodoAmount / 2;
        uint256 amountB = dodoAmount - amountA;

        Exchange exchange = strategyRouter.getExchange();
        dodo.transfer(address(exchange), amountA);
        receivedA = exchange.swap(amountA, address(dodo), address(tokenA), address(this));

        dodo.transfer(address(exchange), amountB);
        receivedB = exchange.swap(amountB, address(dodo), address(tokenB), address(this));

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
        // this is TODO for cases when tokenA and tokenB has different decimals
        uint256 comissionA = (feeAmount * ratioUint) / 1e18;
        uint256 comissionB = feeAmount - comissionA;

        tokenA.transfer(feeAddress, comissionA);
        tokenB.transfer(feeAddress, comissionB);

        return (amountA - comissionA, amountB - comissionB);
    }

    function calculateSwapAmount(uint256 half, uint256 dexFee) private view returns (uint256 amountAfterFee) {
        (uint256 r0, uint256 r1, ) = IUniswapV2Pair(address(lpToken)).getReserves();
        uint256 halfWithFee = (2 * r0 * (dexFee + 1e18)) / ((r0 * (dexFee + 1e18)) / 1e18 + r1);
        uint256 amountB = (half * halfWithFee) / 1e18;
        return amountB;
    }


}