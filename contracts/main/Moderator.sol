//SPDX-License-Identifier: Unlicense

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity ^0.8.0;

contract Moderator is Context, Ownable {
  mapping(address => bool) public moderators;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _setModerator(_msgSender(), true);
    // lock implementation
    // _disableInitializers();
  }

  // function __Moderator_init(address mod) internal virtual initializer {
  //   // __Context_init();
  //   // __Ownable_init();
  //   // _setModerator(mod, true);
  // }

  /**
    @notice Set wallets that will be moderators.
    @dev Admin function.
  */
  function _setModerator(address moderator, bool isWhitelisted) internal virtual {
    require(moderator != address(0), "Zero address");
    bool isModerator = _isModerator();
    if(isWhitelisted) require(!isModerator, "already whitelisted");
    else require(isModerator, "Not whitelisted");
    moderators[moderator] = isWhitelisted;
  }

  /// @notice Whether `who` is a moderator or not
  function _isModerator() internal virtual returns (bool) {
    return moderators[_msgSender()];
  }

}