// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./setup/PaymentRouterSetup.sol";

//solhint-disable func-name-mixedcase
//solhint-disable state-visibility

contract PaymentRouterTest is PaymentRouterSetup {
  uint8 numDevs = 5;
  uint16 numUsers = 100;
  uint16 minTax = 100;
  uint16 maxTax = 10000;
  uint8 erc20Amount = 20;

  function setUp() public {
    super.setUp(numDevs, numUsers);
    paymentRouterDeploy(minTax, maxTax);
    erc20Deploy(erc20Amount);
  }

  function test_CreateSinglePaymentRouter() public {
    //Mint erc20
    erc20Mint(0, address(this), 100e18);

    //Create simple payment route
    address[] memory recipients = new address[](1);
    recipients[0] = address(this);
    uint16[] memory commissions = new uint16[](1);
    commissions[0] = 10000;

    //Create payment route
    bytes32 routeID = paymentRouter.openPaymentRoute(recipients, commissions, 100);

    //Get payment route info
    (address routeCreator, uint16 routeTax, bool isActive) = paymentRouter.paymentRouteID(routeID);
    assertEq(routeCreator, address(this));
    assertEq(routeTax, 100);
    assertTrue(isActive);

    //Get payment route id
    bytes32 returnedRouteID = paymentRouter.getPaymentRouteID(address(this), recipients, commissions);
    assertEq(returnedRouteID, routeID);
  }

  function test_CannotCreateNewRouteIfAlreadyExists() public {
    test_CreateSinglePaymentRouter();
  }

}
