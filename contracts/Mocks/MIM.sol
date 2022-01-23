// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Dependencies/ERC20.sol";

contract MIM is ERC20 {
  constructor() ERC20("Magic Internet Money", "MIM") {}

  function mint(address to, uint256 amount) external {
    _mint(to, amount);
  }
}
