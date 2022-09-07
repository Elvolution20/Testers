//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

  /**
    Mainnet
    DODO Token: https://bscscan.com/address/0x67ee3Cb086F8a16f34beE3ca72FAD36F7Db929e2
    DODO BUSD-USDT Pair https://bscscan.com/address/0xBe60d4c4250438344bEC816Ec2deC99925dEb4c7
  */

interface IDodoV1Router {
    function deposit(address _lpToken, uint256 _amount) external;
    function withdraw(address _lpToken, uint256 _amount) external;
    function withdrawAll(address _lpToken) external;
    function claim(address _lpToken) external;
    function claimAll() external;
    function getUserLpBalance( address _lpToken,  address _user) external view returns (uint256);
    function getPendingReward(address _lpToken, address _user) external view returns (uint256);
    function getAllPendingReward(address _user) external view returns (uint256);
}