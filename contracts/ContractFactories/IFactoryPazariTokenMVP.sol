// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFactoryPazariTokenMVP {

  /**
   * @notice Clones and deploys a PazariTokenMVP contract
   *
   * @param _contractOwners All addresses that will have isAdmin
   * @return newContract The address of the cloned contract
   *
   * @dev All contract owners are granted operator approval and
   * isAdmin status. Marketplace is safe to include, but don't
   * add any other non-Pazari contracts or addresses.
   * @dev It is important to include this factory's address as a
   * contract owner, or else the caller will not have ownership.
   */
  function newPazariTokenMVP(address[] memory _contractOwners) 
    external 
    returns (address newContract);

}