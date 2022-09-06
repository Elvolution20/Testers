// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.0;

/**
  From your contract, call the withdraw function of WithdrawInbox.
  Some explanations of the parameters:
  _wdSeq is a unique identifier for each withdrawal.
  _receiver is the receiver address on _toChain.
  _toChain is the chain ID to receive the tokens withdrawn.
  _fromChains are a list of chain IDs to withdraw the tokens from. We support cross-chain withdrawals, that is to withdraw the liquidity from multiple chains to a single chain.
  _tokens are the token addresses on each chain. Make sure they refer to the same token symbol and they are supported by cBridge on all the chains involved.
  _ratios are the percentages of liquidity to be withdrawn from each chain. They should be all positive. The max ratio is 100000000, which means 100%.
  _slippages are the maximal allowed slippages for cross-chain withdrawals. Usually a small number such as 5000, which means 0.5%, should suffice. The max slippage is 1000000, which means 100%.
 */
interface IPool {
    function addLiquidity(address _token, uint256 _amount) external;

    function withdraws(bytes32 withdrawId) external view returns (bool);

    function withdraw(
        bytes calldata _wdmsg,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external;
}