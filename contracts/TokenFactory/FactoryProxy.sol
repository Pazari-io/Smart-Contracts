/**
 * This is the proxy contract for the ContractFactory contract. The proxy
 * contract forwards all function/value calls to the contract specified at
 * currentAddress, which enables upgradable functionality for the contract.
 * We will want upgradability for the contract factory so we can upgrade
 * our offerings to creators.
 */

//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./FactoryStorage.sol";

contract FactoryProxy is FactoryStorage {
  // Current address where stable version of ContractFactory is located;
  address private currentAddress;
  // Previous address of last stable version of ContractFactory;
  address private previousStableAddress;
  // Array of all previous ContractFactory versions;
  address[] private allPreviousAddresses;

  // Allows factory to pause after upgrade so DAO can check off on change;
  bool private paused;

  constructor(address _currentAddress) {
    currentAddress = _currentAddress;
  }

  // Upgrades ContractFactory to newest version;
  // - upgrade() is restricted to dev wallet;
  // - Upon successful upgrade, the ContractFactory will pause and await
  //   DAO approval to unpause. Until then, nothing else can be done.
  function upgrade(address _newAddress) external {
    require(msg.sender == devWallet, "Only developers can call this function");
    require(!paused, "Contract paused");

    previousStableAddress = currentAddress;
    currentAddress = _newAddress;
    allPreviousAddresses.push(previousStableAddress);

    emit contractUpgraded(_newAddress);
    paused = true;
  }

  // Unpauses contract after a successful upgrade, requires DAO authorization to pass;
  // - isAccepted = true: ContractFactory unpauses and begins operation
  // - isAccepted = false: ContractFactory reverts to previous stable address and unpauses
  function acceptUpgrade(bool isAccepted) external onlyDAO {
    if (isAccepted) {
      paused = false;
      emit contractAccepted(true, currentAddress);
    }
    if (!isAccepted) {
      currentAddress = previousStableAddress;
      paused = false;
      emit contractAccepted(false, currentAddress);
    }
  }

  //solhint-disable no-complex-fallback
  //solhint-disable payable-fallback

  // Redirects all function calls/value to the contract at currentAddress;
  // Auto-locks after an upgrade until DAO accepts the upgrade;
  fallback() external {
    require(!paused, "ContractFactory locked until DAO approves upgrade");
    address implementation = currentAddress;
    require(currentAddress != address(0), "address(0) disallowed");

    assembly {
      calldatacopy(0, 0, calldatasize())
      let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
      returndatacopy(0, 0, returndatasize())
      switch result
      case 0 {
        revert(0, returndatasize())
      }
      default {
        return(0, returndatasize())
      }
    }
  }

  function initializeDAO(address _DAOAddress) external {
    require(msg.sender == devWallet, "Only developers can call this function");
    require(_DAOAddress != address(0), "address(0) disallowed");
    DAOContract = _DAOAddress;
  }
}
