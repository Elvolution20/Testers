//SPDX-License-Identifier: Unlicens
pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {

  // using SafeMath for uint256;

  uint8 public _decimals;

  constructor(uint256 _totalSupply, uint8 decimals_, string memory _name, string memory _symbol) ERC20(_name, _symbol) {
    _mint(msg.sender, _totalSupply);
    _decimals = decimals_;
  }

  function decimals() public view virtual override returns (uint8) {
      return _decimals;
  }

  function mint(address to, uint amount) public {
    _mint(to, amount);
  }

  function burn(uint amount) public {
    _burn(msg.sender, amount);
  }

}