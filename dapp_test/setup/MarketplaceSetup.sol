// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//solhint-disable state-visibility

/* Import lib */
// import "../utils/Hevm.sol";
// import "../utils/MockContract.sol";
// import "../utils/DSTestExtended.sol";

/* Import setups */
// import {UsersSetup} from "./UsersSetup.sol";

/* Import contracts */
// import {Marketplace} from "contracts/Marketplace/Marketplace.sol";
// import {ERC1155PresetMinterPauser} from "contracts/Dependencies/ERC1155PresetMinterPauser.sol";
// import {ERC20PresetMinterPauser} from "contracts/Dependencies/ERC20PresetMinterPauser.sol";

// contract MarketplaceSetup is DSTestExtended, UsersSetup {
//   //Hevm setup
//   Hevm internal constant HEVM = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

//   //Contracts
//   Marketplace marketplace;
//   ERC1155PresetMinterPauser[] erc1155s;
//   ERC20PresetMinterPauser[] erc20s;

//   function setUp(uint8 numDevs, uint16 numUsers) public virtual override {
//     //Set timestamp to 0
//     HEVM.warp(0);

//     //Setup users
//     UsersSetup.setUp(numDevs, numUsers);
//   }

//   function marketplaceDeploy(address paymentRouter) public virtual {
//     marketplace = new Marketplace(paymentRouter);
//   }

//   function erc1155Deploy(uint8 amount) public virtual {
//     for (uint256 i = 0; i < amount; i++) {
//       erc1155s.push(new ERC1155PresetMinterPauser());
//     }
//   }

//   function erc20Deploy(uint8 amount) public virtual {
//     for (uint256 i = 0; i < amount; i++) {
//       erc20s.push(new ERC20PresetMinterPauser("abc", "ABC"));
//     }
//   }

//   function erc1155Mint(
//     uint8 index,
//     address to,
//     uint256 id,
//     uint256 amount
//   ) public virtual {
//     string memory uri = "https://api.pazari.io/metadata/";
//     bytes memory data = "0x";
//     if (index < erc1155s.length) {
//       erc1155s[index].mint(to, id, amount, uri, data);
//     }
//   }

//   function erc20Mint(
//     uint8 index,
//     address to,
//     uint256 amount
//   ) public virtual {
//     if (index < erc20s.length) {
//       erc20s[index].mint(to, amount);
//     }
//   }
// }
