// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/* Import lib */
import "../utils/Hevm.sol";
import "../utils/MockContract.sol";
import "../utils/DSTestExtended.sol";

/* Import dep */
import "contracts/Dependencies/ERC721Holder.sol";
import "contracts/Dependencies/ERC1155Holder.sol";

contract NFTHolder is ERC721Holder, ERC1155Holder {}

//solhint-disable state-visibility
contract User is NFTHolder {
  //Need this to receive ETH
  receive() external payable {}
}
