/**
 * Contract factories have to occupy one contract for each contract type,
 * or else the 24kb size limit is exceeded. This factory produces the
 * ERC721PresetMinterPauserAutoId contract with a modification for IPFS
 * support which allows for unlimited minting of tokens. It is not
 * important for contract factories to be connected to each other,
 * they only need to inherit from FactoryStorage.
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Dependencies/ERC1155PresetMinterPauser.sol";
import "../Dependencies/ERC721PresetMinterPauserAutoId.sol";
import "./FactoryStorage.sol";

contract ContractFactory721 is FactoryStorage {
    // Clones an ERC721PresetMinterPauserAutoId contract with IPFS minting support;
    function newERC721Contract(string memory name, string memory symbol)
        external
        returns (address newContract)
    {
        ERC721PresetMinterPauserAutoId _newContract = new ERC721PresetMinterPauserAutoId(
            name,
            symbol
        );
        newContract = address(_newContract);

        _storeInfo(newContract, 1);
    }
}
