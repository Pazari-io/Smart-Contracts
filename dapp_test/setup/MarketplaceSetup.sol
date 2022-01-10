// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//solhint-disable state-visibility
//solhint-disable reason-string

/* Import lib */
import "../utils/Hevm.sol";
import "../utils/MockContract.sol";
import "../utils/DSTestExtended.sol";

/* Import setups */
import "./UsersSetup.sol";

/* Import contracts */
import {PaymentRouter} from "contracts/PaymentRouter/PaymentRouter.sol";
import {Marketplace} from "contracts/Marketplace/Marketplace.sol";
import {ERC20} from "contracts/Dependencies/ERC20.sol";
import {ERC20PresetMinterPauser} from "contracts/Dependencies/ERC20PresetMinterPauser.sol";
import {ERC1155PresetMinterPauser} from "contracts/Dependencies/ERC1155PresetMinterPauser.sol";
import {ERC1155} from "contracts/Dependencies/ERC1155.sol";
import {PazariTokenMVP} from "contracts/Tokens/PazariTokenMVP.sol";

contract MPUser is User {
  function approveERC20(
    ERC20 erc20,
    address to,
    uint256 amount
  ) public {
    erc20.approve(to, amount);
  }
}

contract MarketplaceSetup is DSTestExtended, MPUser {
  //Hevm setup
  Hevm internal constant HEVM = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

  //Contracts
  PaymentRouter pr;
  Marketplace mp;
  ERC20[] erc20s;
  ERC1155[] erc1155s;

  //Users
  MPUser[] devs;
  MPUser[] users;
  NFTHolder treasury;

  //Settings
  uint8 numDevs = 5;
  uint8 numUsers = 10;
  uint8 erc20Amount = 5;
  uint8 erc1155Amount = 5;
  uint16 minTax = 50;
  uint16 maxTax = 5000;

  function setUp() public virtual {
    //Set timestamp to 0
    HEVM.warp(0);
    HEVM.roll(0);

    //Setup users
    for (uint256 i = 0; i < numDevs; i++) {
      devs.push(new MPUser());
    }
    for (uint256 i = 0; i < numUsers; i++) {
      users.push(new MPUser());
    }
    treasury = new NFTHolder();

    //Deploy contracts
    paymentRouterDeploy(minTax, maxTax);
    marketplaceDeploy(address(pr));
    erc20sDeploy(erc20Amount);
    erc1155sDeploy(erc1155Amount);
  }

  function paymentRouterDeploy(uint16 _minTax, uint16 _maxTax) public virtual {
    address[] memory devsAddr = new address[](devs.length);
    for (uint256 i = 0; i < devs.length; i++) {
      devsAddr[i] = address(devs[i]);
    }
    pr = new PaymentRouter(address(treasury), devsAddr, _minTax, _maxTax);
  }

  function marketplaceDeploy(address prAddr) public virtual {
    mp = new Marketplace(prAddr);
  }

  function erc1155sDeploy(uint8 amount) public virtual {
    for (uint256 i = 0; i < amount; i++) {
      address erc1155Addr = address(new ERC1155PresetMinterPauser());
      erc1155s.push(ERC1155(erc1155Addr));
    }
  }

  function erc20sDeploy(uint8 amount) public virtual {
    for (uint256 i = 0; i < amount; i++) {
      address erc20Addr = address(new ERC20PresetMinterPauser("abc", "ABC"));
      erc20s.push(ERC20(erc20Addr));
    }
  }

  function erc1155Mint(
    uint8 index,
    address to,
    uint256 id,
    uint256 amount
  ) public virtual {
    require(index < erc1155s.length, "Invalid array length");
    string memory uri = "https://api.pazari.io/metadata/";
    bytes memory data = "0x";
    if (index < erc1155s.length) {
      ERC1155PresetMinterPauser erc1155 = ERC1155PresetMinterPauser(address(erc1155s[index]));
      erc1155.mint(to, id, amount, uri, data);
    }
  }

  function erc20Mint(
    uint8 index,
    address to,
    uint256 amount
  ) public virtual {
    require(index < erc20s.length, "Invalid array length");
    ERC20PresetMinterPauser erc20 = ERC20PresetMinterPauser(address(erc20s[index]));
    erc20.mint(to, amount);
  }

  function erc20Mint(
    uint8 index,
    address[] memory to,
    uint256 amount
  ) public virtual {
    require(index < erc20s.length, "Invalid array length");
    ERC20PresetMinterPauser erc20 = ERC20PresetMinterPauser(address(erc20s[index]));
    for (uint256 i = 0; i < to.length; i++) {
      erc20.mint(to[i], amount);
    }
  }

  function createSimpleRoute() public returns (bytes32, address) {
    (bytes32 routeID, address[] memory recipients, ) = createStandardRoute(1, 100);
    return (routeID, recipients[0]);
  }

  function createSimpleRoute(uint16 tax) public returns (bytes32, address) {
    (bytes32 routeID, address[] memory recipients, ) = createStandardRoute(1, tax);
    return (routeID, recipients[0]);
  }

  function createStandardRoute(uint8 num, uint16 tax)
    public
    returns (
      bytes32,
      address[] memory,
      uint16[] memory
    )
  {
    require(num > 0, "num > 0");
    require(tax <= 10000, "tax <= 10000");

    address[] memory recipients = new address[](num);
    uint16[] memory commissions = new uint16[](num);

    uint16 sum = 0;
    for (uint8 i = 0; i < num - 1; i++) {
      recipients[i] = address(new MPUser());
      commissions[i] = 10000 / num;
      sum += 10000 / num;
    }
    recipients[num - 1] = address(new MPUser());
    commissions[num - 1] = 10000 - sum;

    //Create payment route
    bytes32 routeID = pr.openPaymentRoute(recipients, commissions, tax);

    return (routeID, recipients, commissions);
  }
}
