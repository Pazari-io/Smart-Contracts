/**
 * @title FactoryPazariTokenMVP
 *
 * This contract factory produces the PazariTokenMVP contract, which is the
 * primary token contract for Pazari MVP market items.
 */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Tokens/PazariTokenMVP.sol";

contract FactoryPazariTokenMVP {
  /**
   * @notice Clones a new PazariTokenMVP contract
   * @param _contractOwners Array of all addresses that are admins of the new token contract
   *
   * @dev It is very important to include this factory's address in _contractOwners. If not,
   * then the logic in _msgSender() will use msg.sender instead of tx.origin, and the factory
   * will become the originalOwner of the new token contract--thus locking out the contract
   * creator. The alternative is to include the caller's wallet address in _contractOwners.
   */
  function newPazariTokenMVP(address[] memory _contractOwners) external returns (address newContract) {
    PazariTokenMVP _newContract = new PazariTokenMVP(_contractOwners);
    newContract = address(_newContract);
  }
}
