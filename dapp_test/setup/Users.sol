// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract BasicAccount is ERC721Holder, ERC1155Holder {
  constructor(){

  }
}

contract Alice is BasicAccount {
  constructor(){

  }
}

contract Bob is BasicAccount {
  constructor(){

  }
}

contract Dev is BasicAccount {
  constructor(){

  }
}
