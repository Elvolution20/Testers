//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

import "../deps/openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../deps/uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "../deps/uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "../deps/uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/IClipswapFarm.sol";
import "../interfaces/IcBridgeRouter.sol";
import "../interfaces/IWithdrawalBox.sol";
import "../deps/openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../deps/openzeppelin/contracts/security/ReentrancyGuard.sol";

/** @title Stargate USDT Liquidity pool.
        Chain: BSC - https://bscscan.com/address/0xf0FF9888A70f44eb12223A6a55C65976BA7bf854
        Pool: USDT
        Yield Source: Bridge fees and token rewards
        Yield Token: CELR
        Link: https://cbridge.celer.network/liquidity

        Strategy Description:
        USDT is provided as liquidity to the Celer cBridge. This USDT is used as liquidity by people moving between chains.
        Most rewards are received as CELR tokens. Some rewards, which come from bridge fees, are compounded directly into the pool.
        CELR rewards are sold for USDT and USDT is redeposited to strategy to earn fees.
        
        
    @custom:oz-upgrades-unsafe-allow constructor state-variable-immutable
 */
contract CBridgeUSDT is Initializable, UUPSUpgradeable, OwnableUpgradeable, IStrategy {
    error CallerUpgrader();

    address internal upgrader;
    
    ERC20 internal immutable tokenA;
    // ERC20 internal immutable tokenB;
    ERC20 internal immutable lpToken;
    StrategyRouter internal immutable strategyRouter;

    address internal immutable cBridgeRouter;

    ERC20 internal constant celrRewardToken;
    ERC20 internal constant lpToken;
    address internal constant farm;
    IUniswapV2Router02 internal constant celrRouter;

    uint256 internal immutable poolId;

    uint256 private immutable LEFTOVER_THRESHOLD_TOKEN_A;
    uint256 private immutable LEFTOVER_THRESHOLD_TOKEN_B;
    uint256 private constant PERCENT_DENOMINATOR = 10000;

    modifier onlyUpgrader() {
        if (msg.sender != address(upgrader)) revert CallerUpgrader();
        _;
    }

    /// @dev construct is intended to initialize immutables on implementation
    constructor(
        StrategyRouter _strategyRouter,
        uint256 _poolId,
        ERC20 _tokenA,
        ERC20 _tokenB,
        ERC20 _celrRewardToken,
        address _farm,
        ERC20 _celrRouter,
        address _cBridgeRouter
    ) {
        strategyRouter = _strategyRouter;
        poolId = _poolId;
        tokenA = _tokenA;
        tokenB = _tokenB;
        celrRewardToken = _celrRewardToken ;
        farm = _farm;
        celrRouter = _celrRouter;
        cBridgeRouter = _cBridgeRouter;
        LEFTOVER_THRESHOLD_TOKEN_A = 10**_tokenA.decimals();
        LEFTOVER_THRESHOLD_TOKEN_B = 10**_tokenB.decimals();
        
        // lock implementation
        _disableInitializers();
    }

    function initialize(address _upgrader) external initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        upgrader = _upgrader;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyUpgrader {}

    function depositToken() external view override returns (address) {
        return address(tokenA);
    }

    function deposit(uint256 amount) external override onlyOwner {
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        require(IERC20(tokenA).balanceOf(address(this)) >= _amount, "insufficient balance");
        IERC20(_token).safeIncreaseAllowance(bridge, _amount);
        IcBridgeRouter(cBridgeRouter)(bridge).addLiquidity(tokenA, _amount);
        // Exchange exchange = strategyRouter.getExchange();
        celrRewardToken.approve(address(farm), amount);
        farm.deposit(poolId, amount);
    }

    ///@notice The chain Id used here is Testnet
    function withdraw(
        uint64 _wdSeq,
        address _receiver,
        uint64 _toChain,
        uint64[] calldata _fromChains,
        address[] calldata _tokens,
        uint32[] calldata _ratios,
        uint32[] calldata _slippages,
        uint256 strategyTokenAmountToWithdraw
    )
        external
        override
        onlyOwner
        returns (uint256 amountWithdrawn)
    {
       
        IClipswapFarm(farm).withdraw(_p.poolId, amtToWithdraw);
        // celrRewardToken.approve(address(celrRouter), amtToWithdraw);
        IWithdrawInbox(inbox).withdraw(_wdSeq, _receiver, _toChain, _fromChains, _tokens, _ratios, _slippages);
        lpToken.approve(address(celrRouter), amtToWithdraw);
        uint bal = celrRewardToken.balanceOf(address(this));

        Exchange exchange = strategyRouter.getExchange();
        celrRewardToken.transfer(address(exchange), bal);
        uint amountA = exchange.swap(bai, address(celrRewardToken), address(tokenA), address(this));
        tokenA.transfer(msg.sender, amountA);
       
        return amountA;
    }

    function compound() external override onlyOwner {
        // inside withdraw happens STG rewards collection
        farm.withdraw(poolId, 0);
        // use balance because STG is harvested on deposit and withdraw calls
        uint256 stgAmount = stg.balanceOf(address(this));

        if (stgAmount > 0) {
            fix_leftover(0);
            sellReward(stgAmount);
            uint256 balanceA = tokenA.balanceOf(address(this));
            uint256 balanceB = celrRewardToken.balanceOf(address(this));

            tokenA.approve(address(cBridgeRouter), balanceA);
            // tokenB.approve(address(celrRouter), balanceB);
            IcBridgeRouter(cBridgeRouter).addLiquidity(_p.poolId, balanceA, address(this));

            uint256 lpAmount = lpToken.balanceOf(address(this));
            lpToken.approve(address(farm), lpAmount);
            farm.deposit(poolId, lpAmount);
        }
    }


    function withdrawAll(uint256 destinationPoolId, uint lpAmountToRedeem) external override onlyOwner returns (uint256 amountWithdrawn) {
        (uint256 amount, ) = farm.userInfo(poolId, address(this));
        if (amount > 0) {
            farm.withdraw(poolId, amount);
            uint256 lpAmount = lpToken.balanceOf(address(this));
            lpToken.approve(address(celrRouter), lpAmount);
            IcBridgeRouter(cBridgeRouter).redeemLocal(
                chainId, 
                poolId, 
                destinationPoolId, 
                address(this), 
                lpAmountToRedeem, 
                abi.encode(address(this)), 
                lzTxObj(0, 0, "")
            );
        }

        uint256 amountA = tokenA.balanceOf(address(this));
        uint256 amountB = celrRewardToken.balanceOf(address(this));

        if (amountB > 0) {
            Exchange exchange = strategyRouter.getExchange();
            celrRewardToken.transfer(address(exchange), amountB);
            amountA += exchange.swap(amountB, address(celrRewardToken), address(tokenA), address(this));
        }
        if (amountA > 0) {
            tokenA.transfer(msg.sender, amountA);
            return amountA;
        }
    }

    /// @dev Swaps leftover tokens for a better ratio for LP.
    function fix_leftover(uint256 amountIgnore) private {
        Exchange exchange = strategyRouter.getExchange();
        uint256 amountB = celrRewardToken.balanceOf(address(this));
        uint256 amountA = tokenA.balanceOf(address(this)) - amountIgnore;
        uint256 toSwap;
        if (amountB > amountA && (toSwap = amountB - amountA) > LEFTOVER_THRESHOLD_TOKEN_B) {
            uint256 dexFee = exchange.getFee(toSwap / 2, address(tokenA), address(celrRewardToken));
            toSwap = calculateSwapAmount(toSwap / 2, dexFee);
            celrRewardToken.transfer(address(exchange), toSwap);
            exchange.swap(toSwap, address(celrRewardToken), address(tokenA), address(this));
        } else if (amountA > amountB && (toSwap = amountA - amountB) > LEFTOVER_THRESHOLD_TOKEN_A) {
            uint256 dexFee = exchange.getFee(toSwap / 2, address(tokenA), address(celrRewardToken));
            toSwap = calculateSwapAmount(toSwap / 2, dexFee);
            tokenA.transfer(address(exchange), toSwap);
            exchange.swap(toSwap, address(tokenA), address(celrRewardToken), address(this));
        }
    }

    // swap celrRewardToken for tokenA & tokenB in proportions 50/50
    function sellReward(uint256 celrRewardTokenAmount) private returns (uint256 receivedA, uint256 receivedB) {
        // sell for lp ratio
        uint256 amountA = celrRewardTokenAmount / 2;
        uint256 amountB = celrRewardTokenAmount - amountA;

        Exchange exchange = strategyRouter.getExchange();
        celrRewardToken.transfer(address(exchange), amountA);
        receivedA = exchange.swap(amountA, address(celrRewardToken), address(tokenA), address(this));

        celrRewardToken.transfer(address(exchange), amountB);
        receivedB = exchange.swap(amountB, address(celrRewardToken), address(tokenB), address(this));

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
        (uint256 r0, uint256 r1, ) = IUniswapV2Pair(address(celrRewardToken)).getReserves();
        uint256 halfWithFee = (2 * r0 * (dexFee + 1e18)) / ((r0 * (dexFee + 1e18)) / 1e18 + r1);
        uint256 amountB = (half * halfWithFee) / 1e18;
        return amountB;
    }
}

