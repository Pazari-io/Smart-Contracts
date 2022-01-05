/**
 * @title FactoryPazariTokenMVP Version 0.0.1 (TESTNET ONLY)
 *
 * This contract factory produces the PazariTokenMVP contract, which is the
 * primary token contract for Pazari MVP market items. Since PazariTokenMVP
 * is a large contract, we only have room to fit the clone function here
 * and not much else.
 *
 * PazariTokenMVP is contract ID 0.
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Tokens/PazariTokenMVP.sol";

contract FactoryPazariTokenMVP {
  function newPazariTokenMVP(address[] memory _contractOwners) external returns (address newContract) {
    PazariTokenMVP _newContract = new PazariTokenMVP(_contractOwners);
    newContract = address(_newContract);
  }
}
