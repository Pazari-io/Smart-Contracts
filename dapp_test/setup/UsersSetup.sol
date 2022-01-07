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

contract Treasury is NFTHolder {}

contract Dev is NFTHolder {}

contract User is NFTHolder {}

//solhint-disable state-visibility
contract UsersSetup is NFTHolder {
  //Users
  Dev[] devs;
  User[] users;
  address[] devsAddr;
  address[] usersAddr;

  //Treasury
  Treasury treasury;

  //Need this to receive ETH
  receive() external payable {}

  function setUp(uint8 numDevs, uint16 numUsers) public virtual {
    //Setup treasury
    treasury = new Treasury();

    //Setup accounts
    for (uint256 i = 0; i < numDevs; i++) {
      devs.push(new Dev());
      devsAddr.push(address(devs[i]));
    }
    for (uint256 i = 0; i < numUsers; i++) {
      users.push(new User());
      usersAddr.push(address(users[i]));
    }
  }
}
