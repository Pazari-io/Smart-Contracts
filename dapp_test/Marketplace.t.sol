// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./setup/MarketplaceSetup.sol";

//solhint-disable func-name-mixedcase
//solhint-disable state-visibility
//solhint-disable no-unused-vars

contract CreateMarketItemTest is MarketplaceSetup {
  function test_oneType() public {
    //Mint erc20 and erc1155
    erc1155Mint(0, address(this), 0, 100);
    erc20Mint(0, address(this), 100e18);

    //Give operator approval
    erc1155s[0].setApprovalForAll(address(mp), true);

    //Create simple payment route
    (bytes32 routeID, ) = createSimpleRoute();

    //Create simple market item
    uint256 itemID = mp.createMarketItem(
      address(erc1155s[0]),
      address(this),
      0,
      50,
      1e18,
      address(erc20s[0]),
      true,
      true,
      routeID,
      5,
      true
    );

    assertEq(itemID, 1);
  }
}
