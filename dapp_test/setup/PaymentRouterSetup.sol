// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//solhint-disable state-visibility

/* Import lib */
import "../utils/Hevm.sol";
import "../utils/MockContract.sol";
import "../utils/DSTestExtended.sol";

/* Import setups */
import "./UsersSetup.sol";

/* Import contracts */
import {PaymentRouter} from "contracts/PaymentRouter/PaymentRouter.sol";
import {ERC20PresetMinterPauser} from "contracts/Dependencies/ERC20PresetMinterPauser.sol";

contract PaymentRouterSetup is DSTestExtended, UsersSetup {
  //Hevm setup
  Hevm internal constant HEVM = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

  //Contracts
  PaymentRouter pr;
  ERC20PresetMinterPauser[] erc20s;
  address[] erc20sAddr;

  function setUp(uint8 numDevs, uint16 numUsers) public virtual override {
    //Set timestamp to 0
    HEVM.warp(0);
    HEVM.roll(0);

    //Setup users
    UsersSetup.setUp(numDevs, numUsers);
  }

  function paymentRouterDeploy(uint16 minTax, uint16 maxTax) public virtual {
    pr = new PaymentRouter(address(treasury), devsAddr, minTax, maxTax);
  }

  function erc20Deploy(uint8 amount) public virtual {
    for (uint256 i = 0; i < amount; i++) {
      erc20s.push(new ERC20PresetMinterPauser("abc", "ABC"));
      erc20sAddr.push(address(erc20s[i]));
    }
  }

  function erc20Mint(
    uint8 index,
    address to,
    uint256 amount
  ) public virtual {
    if (index < erc20s.length) {
      erc20s[index].mint(to, amount);
    }
  }
}
