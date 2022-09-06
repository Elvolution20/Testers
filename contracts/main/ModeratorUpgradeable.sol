//SPDX-License-Identifier: Unlicense

import "../deps/openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "../deps/UUPSUpgradeable.sol";

pragma solidity ^0.8.0;

contract ModeratorUpgradeable is Initializable, ContextUpgradeable, UUPSUpgradeable {
  mapping(address => bool) public moderators;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    // lock implementation
    _disableInitializers();
  }

  function initialize () external  initializer {
    __Context_init();
    __UUPSUpgradeable_init();
    _setModerator(_msgSender(), true);
  }

  /**
    @notice Set wallets that will be moderators.
    @dev Admin function.
  */
  function _setModerator(address moderator, bool isWhitelisted, address expected) internal virtual {
    _modifier(moderator, expected);
    bool isModerator = _isModerator(moderator);
    if(isWhitelisted) require(!isModerator, "already whitelisted");
    else require(isModerator, "Not whitelisted");
    moderators[moderator] = isWhitelisted;
  }

  /// @notice Hook
  function _modifier(address newModerator, address expected) internal virtual {
    require(expected != address(0) && _msgSender() == expected, "Not authorized");
  }

  /// @notice Whether `who` is a moderator or not
  function _isModerator() internal virtual returns (bool) {
    return moderators[_msgSender()];
  }

}