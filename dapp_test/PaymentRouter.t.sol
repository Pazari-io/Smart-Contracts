// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./setup/PaymentRouterSetup.sol";

import "contracts/Dependencies/IERC20.sol";

//solhint-disable func-name-mixedcase
//solhint-disable state-visibility
//solhint-disable no-unused-vars

contract OpenRouteTest is PaymentRouterSetup {
  function test_oneRecipient() public {
    //Create simple payment route
    address[] memory recipients = new address[](1);
    recipients[0] = address(users[0]);
    uint16[] memory commissions = new uint16[](1);
    commissions[0] = 10000;

    //Create payment route
    bytes32 routeID = pr.openPaymentRoute(recipients, commissions, 100);

    //Get payment route info
    (address routeCreator, uint16 routeTax, PaymentRouter.TAXTYPE taxType, bool isActive) = pr.paymentRouteID(
      routeID
    );
    assertEq(routeCreator, address(this));
    assertEq(routeTax, 100);
    assertTrue(taxType == PaymentRouter.TAXTYPE.CUSTOM);
    assertTrue(isActive);

    //Get payment route id
    bytes32 computedRouteID = pr.getPaymentRouteID(address(this), recipients, commissions);
    assertEq(computedRouteID, routeID);

    bytes32 storedRouteID = pr.creatorRoutes(address(this), 0);
    assertEq(storedRouteID, routeID);

    bytes32[] memory myPaymentRoutes = pr.getMyPaymentRoutes();
    assertEq(myPaymentRoutes[0], routeID);
  }

  function test_manyRecipientsWithEqualCommissions(uint8 num) public {
    //Avoid this case
    if (num == 0 || num > 50) return;

    //Create standard route
    bytes32 routeID;
    address[] memory recipients;
    uint16[] memory commissions;
    (routeID, recipients, commissions) = createStandardRoute(num, 100);

    //Check route info
    address routeCreator;
    uint16 routeTax;
    PaymentRouter.TAXTYPE taxType;
    bool isActive;
    (routeCreator, routeTax, taxType, isActive) = pr.paymentRouteID(routeID);
    assertEq(routeCreator, address(this));
    assertEq(routeTax, 100);
    assertTrue(taxType == PaymentRouter.TAXTYPE.CUSTOM);
    assertTrue(isActive);

    //Check route id computation
    bytes32 computedRouteID = pr.getPaymentRouteID(address(this), recipients, commissions);
    assertEq(computedRouteID, routeID);

    //Check if route id is stored correctly
    bytes32[] memory myPaymentRoutes = pr.getMyPaymentRoutes();
    assertEq(myPaymentRoutes[0], routeID);
  }

  function test_tooManyRecipients() public {
    uint256 ppl = 260;
    address[] memory recipients = new address[](ppl);
    uint16[] memory commissions = new uint16[](ppl);
    for (uint256 i = 0; i < ppl; i++) {
      recipients[i] = address(new User());
      commissions[i] = uint16(10000 / ppl);
    }

    try pr.openPaymentRoute(recipients, commissions, 100) {
      fail();
    } catch Error(string memory error) {
      assertEq(error, "Max recipients exceeded");
    }
  }

  function test_invalidArrayLength() public {
    uint256 ppl = 5;
    address[] memory recipients = new address[](ppl);
    uint16[] memory commissions = new uint16[](ppl + 1);
    for (uint256 i = 0; i < ppl; i++) {
      recipients[i] = address(new User());
      commissions[i] = uint16(10000 / ppl);
    }

    try pr.openPaymentRoute(recipients, commissions, 100) {
      fail();
    } catch Error(string memory error) {
      assertEq(error, "Array lengths must match");
    }
  }

  function test_commissionTooBig() public {
    address[] memory recipients = new address[](1);
    recipients[0] = address(users[0]);
    uint16[] memory commissions = new uint16[](1);
    commissions[0] = 10001;

    try pr.openPaymentRoute(recipients, commissions, 100) {
      fail();
    } catch Error(string memory error) {
      assertEq(error, "Commissions cannot add up to more than 100%");
    }
  }

  function test_noZeroAddress() public {
    address[] memory recipients = new address[](1);
    uint16[] memory commissions = new uint16[](1);
    commissions[0] = 10000;

    try pr.openPaymentRoute(recipients, commissions, 100) {
      fail();
    } catch Error(string memory error) {
      assertEq(error, "Cannot burn tokens with payment router");
    }
  }

  function test_commissionsDontAddUpTo10000() public {
    uint256 ppl = 100;
    address[] memory recipients = new address[](ppl);
    uint16[] memory commissions = new uint16[](ppl);
    for (uint256 i = 0; i < ppl; i++) {
      recipients[i] = address(new User());
      commissions[i] = uint16(10000 / ppl);
    }
    commissions[ppl - 1] = commissions[ppl - 1] - 1;

    try pr.openPaymentRoute(recipients, commissions, 100) {
      fail();
    } catch Error(string memory error) {
      assertEq(error, "Commissions don't add up to 100%");
    }
  }

  function test_taxTooLarge() public {
    address[] memory recipients = new address[](1);
    recipients[0] = address(users[0]);
    uint16[] memory commissions = new uint16[](1);
    commissions[0] = 10000;

    try pr.openPaymentRoute(recipients, commissions, 10001) {
      fail();
    } catch Error(string memory error) {
      assertEq(error, "Tax cannot be larger than 10000");
    }
  }

  function test_minTax() public {
    //Open PR with min tax
    (bytes32 routeID, , ) = createStandardRoute(1, 0);

    (, uint16 routeTax, PaymentRouter.TAXTYPE taxType, ) = pr.paymentRouteID(routeID);
    assertEq(routeTax, minTax);
    assertTrue(taxType == PaymentRouter.TAXTYPE.MINTAX);
  }

  function test_maxTax() public {
    //Open PR with max tax
    (bytes32 routeID, , ) = createStandardRoute(1, 10000);

    (, uint16 routeTax, PaymentRouter.TAXTYPE taxType, ) = pr.paymentRouteID(routeID);
    assertEq(routeTax, maxTax);
    assertTrue(taxType == PaymentRouter.TAXTYPE.MAXTAX);
  }

  function test_createDuplicateRoutes() public {
    //Create simple payment route
    address[] memory recipients = new address[](2);
    recipients[0] = address(users[0]);
    recipients[1] = address(users[1]);
    uint16[] memory commissions = new uint16[](2);
    commissions[0] = 3000;
    commissions[1] = 7000;

    //Create payment route
    bytes32 routeID1;
    bytes32 routeID2;
    routeID1 = pr.openPaymentRoute(recipients, commissions, 100);
    routeID2 = pr.openPaymentRoute(recipients, commissions, 100);
    assertEq(routeID1, routeID2);
  }
}

contract ModifyRouteTest is PaymentRouterSetup {
  function test_closeRoute() public {
    (bytes32 routeID, ) = createSimpleRoute();

    pr.togglePaymentRoute(routeID);

    (, , , bool isActive) = pr.paymentRouteID(routeID);
    assertFalse(isActive);
  }

  function test_closeRoute_onlyCreator() public {
    (bytes32 routeID, ) = createSimpleRoute();

    try users[0].togglePaymentRoute(pr, routeID) {
      fail();
    } catch Error(string memory error) {
      assertEq(error, "Unauthorized, only creator");
    }
  }

  function test_adjustRouteTax_max() public {
    (bytes32 routeID, ) = createSimpleRoute();

    bool success = pr.adjustRouteTax(routeID, 10000);
    assertTrue(success);

    (, uint16 routeTax, PaymentRouter.TAXTYPE taxType, ) = pr.paymentRouteID(routeID);
    assertEq(routeTax, maxTax);
    assertTrue(taxType == PaymentRouter.TAXTYPE.MAXTAX);
  }

  function test_adjustRouteTax_min() public {
    (bytes32 routeID, ) = createSimpleRoute();

    bool success = pr.adjustRouteTax(routeID, 0);
    assertTrue(success);

    (, uint16 routeTax, PaymentRouter.TAXTYPE taxType, ) = pr.paymentRouteID(routeID);
    assertEq(routeTax, minTax);
    assertTrue(taxType == PaymentRouter.TAXTYPE.MINTAX);
  }

  function test_adjustRouteTax_custom(uint16 newTax) public {
    if (newTax >= maxTax || newTax <= minTax) {
      return;
    }

    (bytes32 routeID, ) = createSimpleRoute();

    bool success = pr.adjustRouteTax(routeID, newTax);
    assertTrue(success);

    (, uint16 routeTax, PaymentRouter.TAXTYPE taxType, ) = pr.paymentRouteID(routeID);
    assertEq(routeTax, newTax);
    assertTrue(taxType == PaymentRouter.TAXTYPE.CUSTOM);
  }

  function test_adjustRouteTax_onlyCreator() public {
    (bytes32 routeID, ) = createSimpleRoute();

    try users[0].adjustRouteTax(pr, routeID, 3333) {
      fail();
    } catch Error(string memory error) {
      assertEq(error, "Unauthorized, only creator");
    }
  }

  function test_adjustTaxBounds_basic(uint16 _minTax, uint16 _maxTax) public {
    if (_minTax >= _maxTax || _maxTax > 10000) {
      return;
    }

    devs[0].adjustTaxBounds(pr, _minTax, _maxTax);

    assertEq(pr.maxTax(), _maxTax);
    assertEq(pr.minTax(), _minTax);
  }

  function test_adjustTaxBounds_onlyDev() public {
    try users[0].adjustTaxBounds(pr, 0, 10000) {
      fail();
    } catch Error(string memory error) {
      assertEq(error, "Only developers can access this function");
    }
  }
}

contract PushTokensTest is PaymentRouterSetup {
  function test_simpleRoute(uint128 _amount) public {
    //Mint token to sender
    PRUser sender = users[0];
    ERC20 erc20 = erc20s[0];
    uint256 amount = uint256(_amount);
    erc20Mint(0, address(sender), amount);

    //Create router
    (bytes32 routeID, address recipient) = createSimpleRoute();

    //Sender approves token transfer to pr
    sender.approveERC20(erc20, address(pr), amount);
    //Sender pushes token to pr
    bool success = pr.pushTokens(routeID, address(erc20), address(sender), amount);

    //Check
    assertTrue(success);
    assertEq(erc20.balanceOf(address(treasury)), (amount * 100) / 10000);
    assertEq(erc20.balanceOf(address(recipient)), amount - (amount * 100) / 10000);
  }

  function test_pushToClosedRoute() public {
    //Mint token to sender
    PRUser sender = users[0];
    ERC20 erc20 = erc20s[0];
    uint256 amount = 1e18;
    erc20Mint(0, address(sender), amount);

    //Create route
    (bytes32 routeID, ) = createSimpleRoute();

    //Close route
    pr.togglePaymentRoute(routeID);

    //User1 approve token transfer to pr
    sender.approveERC20(erc20, address(pr), amount);

    //User1 push token to pr
    try pr.pushTokens(routeID, address(erc20), address(sender), amount) {
      fail();
    } catch Error(string memory error) {
      assertEq(error, "Error: Route inactive");
    }
  }

  function test_failedTransfer(uint128 _amount) public {
    //Calculate amount
    uint256 amount = uint256(_amount);
    uint256 taxAmount = (amount * 100) / 10000;
    uint256 totalAmount = amount - taxAmount;

    //Create route
    (bytes32 routeID, address recipient) = createSimpleRoute();

    //Setup accounts & contract
    User sender = users[0];
    MockContract erc20 = new MockContract();
    erc20.givenMethodReturnBool(
      abi.encodeWithSelector(IERC20.transferFrom.selector, address(sender), address(pr), amount),
      true
    );
    erc20.givenMethodReturnBool(
      abi.encodeWithSelector(IERC20.transfer.selector, address(treasury), taxAmount),
      true
    );
    erc20.givenMethodReturnBool(
      abi.encodeWithSelector(IERC20.transfer.selector, address(recipient), totalAmount),
      false
    );

    bool success = pr.pushTokens(routeID, address(erc20), address(sender), amount);
    assertTrue(success);

    //Check failed transfer
    assertEq(pr.tokenBalanceToCollect(address(recipient), address(erc20)), totalAmount);
  }
}

contract HoldsTokensTest is PaymentRouterSetup {
  function test_simpleRoute(uint128 _amount) public {
    //Mint token to sender
    PRUser sender = users[0];
    ERC20 erc20 = erc20s[0];
    uint256 amount = uint256(_amount);
    erc20Mint(0, address(sender), amount);

    //Create router
    (bytes32 routeID, address recipient) = createSimpleRoute();

    //User1 approve token transfer to pr
    sender.approveERC20(erc20, address(pr), amount);
    //User1 push token to pr
    bool success = pr.holdTokens(routeID, address(erc20), address(sender), amount);

    assertTrue(success);
    assertEq(erc20.balanceOf(address(treasury)), (amount * 100) / 10000);
    assertEq(erc20.balanceOf(address(recipient)), 0);
    assertEq(erc20.balanceOf(address(pr)), amount - (amount * 100) / 10000);
  }
}

contract PullTokensTest is PaymentRouterSetup {
  function test_simpleRoute(uint128 _amount) public {
    if (_amount == 0) return;

    //Mint token to sender
    PRUser sender = users[0];
    ERC20 erc20 = erc20s[0];
    uint256 amount = uint256(_amount);
    erc20Mint(0, address(sender), amount);

    //Create router
    (bytes32 routeID, address recipient) = createSimpleRoute();

    //User1 approve token transfer to pr
    sender.approveERC20(erc20, address(pr), amount);
    //User1 push token to pr
    pr.holdTokens(routeID, address(erc20), address(sender), amount);

    bool success = toPRUser(recipient).pullTokens(pr, address(erc20));
    assertTrue(success);

    assertEq(erc20.balanceOf(recipient), amount - (amount * 100) / 10000);
    assertEq(erc20.balanceOf(address(pr)), 0);
  }
}
