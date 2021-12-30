// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./setup/MarketplaceSetup.sol";

//solhint-disable func-name-mixedcase
//solhint-disable state-visibility

contract MarketplaceTest is MarketplaceSetup {
  uint8 numDevs = 5;
  uint16 numUsers = 100;
  uint16 minTax = 100;
  uint16 maxTax = 10000;
  uint8 erc1155Amount = 10;
  uint8 erc20Amount = 20;

  function setUp() public {
    super.setUp(numDevs, numUsers);
    marketplaceDeploy(minTax, maxTax);
    erc1155Deploy(erc1155Amount);
    erc20Deploy(erc20Amount);
  }

  function test_Basic_CreateMarketItem() public {
    //Mint erc20 and erc1155
    erc1155Mint(0, address(this), 0, 100);
    erc20Mint(0, address(this), 100e18);

    //Give operator approval
    erc1155s[0].setApprovalForAll(address(marketplace), true);

    //Create simple payment route
    address[] memory recipients = new address[](1);
    recipients[0] = address(this);
    uint16[] memory commissions = new uint16[](1);
    commissions[0] = 10000;

    bytes32 routeID = marketplace.openPaymentRoute(recipients, commissions, 100);

    //Create simple market item
    uint256 itemID = marketplace.createMarketItem(
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
