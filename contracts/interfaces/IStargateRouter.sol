//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;
pragma abicoder v2;

interface IStargateRouter {
  struct lzTxObj {
    uint256 dstGasForCall;
    uint256 dstNativeAmmount;
    bytes dstNativeAddr;
  }

  function addLiquidity(uint256 _poolId, uint256 _amountLD, address _to) external;
  
  function swap(
    uint16 _dstChainId,
    uint256 _srcPoolId,
    uint256 _dstPoolId,
    address payable _refundAddress,
    uint256 amountLD,
    uint256 _minAmountLD,
    lzTxObj memory _lzTxParams,
    bytes calldata _to,
    bytes calldata _payLoad
  ) external payable;

  function redeemRemote(
    uint16 _dstChainId,
    uint256 _srcPoolId,
    uint256 _dstPoolId,
    address payable _refundAddress,
    uint256 amountLP,
    uint256 _minAmountLD,
    bytes calldata _to,
    lzTxObj memory _lzTxParams
  ) external payable;

  function instantRedeemLocal(
    uint256 _srcPoolId,
    uint256 amountLP,
    bytes calldata _to
  ) external returns(uint256);

  function redeemLocal(
    uint16 _dstChainId,
    uint256 _srcPoolId,
    uint256 _dstPoolId,
    address payable _refundAddress,
    uint256 amountLP,
    bytes calldata _to,
    lzTxObj memory _lzTxParams
  ) external payable;

  function sendCredits(
    uint16 _dstChainId,
    uint256 _srcPoolId,
    uint256 _dstPoolId,
    address payable _refundAddress
  ) external payable;

  function quoteLayerZeroFee(
    uint16 _dstChainId,
    uint8 _functionType,
    bytes calldata _toAddress,
    bytes calldata _transferAndCallPayload,
    lzTxObj memory _lzTxParams
  ) external view returns (uint256, uint256);
}