/**
 * Contract factories have to occupy one contract for each contract type,
 * or else the 24kb size limit is exceeded. This factory produces the
 * ERC1155PresetMinterPauser contract with a modification for IPFS
 * support which allows for unlimited minting of tokens. It is not
 * important for contract factories to be connected to each other,
 * they only need to inherit from FactoryStorage.
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Dependencies/ERC1155PresetMinterPauser.sol";
import "../Dependencies/ERC721PresetMinterPauserAutoId.sol";
import "./FactoryStorage.sol";

contract ContractFactory1155 is FactoryStorage {
  // Clones an ERC1155PresetMinterPauser contract with IPFS minting support;
  function newERC1155Contract() external returns (address newContract) {
    ERC1155PresetMinterPauser _newContract = new ERC1155PresetMinterPauser();
    newContract = address(_newContract);

    _storeInfo(newContract, 0);
  }
}
