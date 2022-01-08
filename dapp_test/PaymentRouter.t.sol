// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./setup/PaymentRouterSetup.sol";

import "contracts/Dependencies/IERC20.sol";

//solhint-disable func-name-mixedcase
//solhint-disable state-visibility
//solhint-disable no-unused-vars

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

  function test_createRoute_basic() public returns (bytes32) {
    //Create simple payment route
    address[] memory recipients = new address[](1);
    recipients[0] = usersAddr[0];
    uint16[] memory commissions = new uint16[](1);
    commissions[0] = 10000;

    //Create payment route
    bytes32 routeID = pr.openPaymentRoute(recipients, commissions, 100);

    //Get payment route info
    (address routeCreator, uint16 routeTax, bool isActive) = pr.paymentRouteID(routeID);
    assertEq(routeCreator, address(this));
    assertEq(routeTax, 100);
    assertTrue(isActive);

    //Get payment route id
    bytes32 returnedRouteID = pr.getPaymentRouteID(address(this), recipients, commissions);
    assertEq(returnedRouteID, routeID);

    return routeID;
  }

  function test_createRoute_tooManyRecipients() public {
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

  function test_createRoute_invalidArrayLength() public {
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

  function test_createRoute_commissionTooBig() public {
    address[] memory recipients = new address[](1);
    recipients[0] = usersAddr[0];
    uint16[] memory commissions = new uint16[](1);
    commissions[0] = 10001;

    try pr.openPaymentRoute(recipients, commissions, 100) {
      fail();
    } catch Error(string memory error) {
      assertEq(error, "Commissions cannot add up to more than 100%");
    }
  }

  function test_createRoute_noZeroAddress() public {
    address[] memory recipients = new address[](1);
    uint16[] memory commissions = new uint16[](1);
    commissions[0] = 10000;

    try pr.openPaymentRoute(recipients, commissions, 100) {
      fail();
    } catch Error(string memory error) {
      assertEq(error, "Cannot burn tokens with payment router");
    }
  }

  function test_createRoute_commissionsDontAddUpTo10000() public {
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

  function test_createRoute_duplicateRoutes() public {
    //Create simple payment route
    address[] memory recipients = new address[](2);
    recipients[0] = usersAddr[0];
    recipients[1] = usersAddr[1];
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

  function test_closeRoute_basic() public returns (bytes32) {
    bytes32 routeID = test_createRoute_basic();

    pr.togglePaymentRoute(routeID);

    (, , bool isActive) = pr.paymentRouteID(routeID);
    assertFalse(isActive);

    return routeID;
  }

  function test_closeRoute_onlyCreator() public {
    bytes32 routeID = test_createRoute_basic();

    try users[0].togglePaymentRoute(pr, routeID) {
      fail();
    } catch Error(string memory error) {
      assertEq(error, "Unauthorized, only creator");
    }
  }

  function test_pushTokens_basic(uint128 _amount) public returns (bytes32) {
    uint256 amount = uint256(_amount);
    User sender = users[1];
    User recipient = users[0];
    erc20Mint(0, address(sender), amount);

    //Create router
    bytes32 routeID = test_createRoute_basic();
    //User1 approve token transfer to pr
    sender.approveERC20(erc20s[0], address(pr), amount);
    //User1 push token to pr
    bool success = pr.pushTokens(routeID, erc20sAddr[0], address(sender), amount);
    assertTrue(success);

    assertEq(erc20s[0].balanceOf(address(treasury)), (amount * 100) / 10000);
    assertEq(erc20s[0].balanceOf(address(recipient)), amount - (amount * 100) / 10000);

    return routeID;
  }

  function test_pushTokens_closedRoute() public {
    uint256 amount = 1e18;
    User sender = users[1];
    erc20Mint(0, address(sender), amount);

    //Create router
    bytes32 routeID = test_createRoute_basic();
    //Close route
    pr.togglePaymentRoute(routeID);

    //User1 approve token transfer to pr
    sender.approveERC20(erc20s[0], address(pr), amount);

    //User1 push token to pr
    try pr.pushTokens(routeID, erc20sAddr[0], address(sender), amount) {
      fail();
    } catch Error(string memory error) {
      assertEq(error, "Route inactive");
    }
  }

  function test_pushTokens_FailedTransfer(uint128 _amount) public {
    uint256 amount = uint256(_amount);
    User sender = users[1];
    User recipient = users[0];

    MockContract erc20 = new MockContract();

    uint256 taxAmount = (amount * 100) / 10000;
    uint256 totalAmount = amount - taxAmount;

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

    //Create router
    bytes32 routeID = test_createRoute_basic();
    bool success = pr.pushTokens(routeID, address(erc20), address(sender), amount);
    assertTrue(success);

    assertEq(pr.tokenBalanceToCollect(address(recipient), address(erc20)), totalAmount);
  }

  function test_holdTokens_basic(uint128 _amount) public returns (bytes32) {
    //Mint to user 1
    uint256 amount = uint256(_amount);
    User sender = users[1];
    User recipient = users[0];
    erc20Mint(0, address(sender), amount);

    //Create router
    bytes32 routeID = test_createRoute_basic();
    //User1 approve token transfer to pr
    sender.approveERC20(erc20s[0], address(pr), amount);
    //User1 push token to pr
    bool success = pr.holdTokens(routeID, erc20sAddr[0], address(sender), amount);
    assertTrue(success);

    assertEq(erc20s[0].balanceOf(address(treasury)), (amount * 100) / 10000);
    assertEq(erc20s[0].balanceOf(address(recipient)), 0);
    assertEq(erc20s[0].balanceOf(address(pr)), amount - (amount * 100) / 10000);

    return routeID;
  }

  function test_pullTokens_basic(uint128 _amount) public {
    if (_amount == 0) return;

    uint256 amount = uint256(_amount);
    User recipient = users[0];
    test_holdTokens_basic(_amount);

    bool success = recipient.pullTokens(pr, erc20sAddr[0]);
    assertTrue(success);

    assertEq(erc20s[0].balanceOf(address(recipient)), amount - (amount * 100) / 10000);
    assertEq(erc20s[0].balanceOf(address(pr)), 0);
  }

  // function test_createRoute_ManyRecipients(uint8 num) public {
  //   //Avoid this case
  //   if (num % 2 != 0) return;

  //   //Create simple payment route
  //   address[] memory recipients = new address[](num);
  //   uint16[] memory commissions = new uint16[](num);

  //   for(int i = 0; i < num; i++){
  //     recipients[i] = address(new User());
  //     commissions[i] = 10000 / num;
  //   }

  //   //Create payment route
  //   bytes32 routeID = pr.openPaymentRoute(recipients, commissions, 100);
  //   assertEq(routeCreator, address(this));
  //   assertEq(routeTax, 100);
  //   assertTrue(isActive);
  // }
}
