/**
 * @dev Interface for interacting with any PazariTokenMVP contract.
 *
 * Inherits from IERC1155MetadataURI, therefore all IERC1155 function 
 * calls will work on a Pazari token. The IPazariTokenMVP interface 
 * accesses the Pazari-specific functions of a Pazari token.
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Dependencies/IERC1155MetadataURI.sol";

interface IPazariTokenMVP is IERC1155MetadataURI {

    /**
     * @dev Struct to track token properties.
     */
    struct TokenProps {
        string uri; // IPFS URI where public metadata is located
        uint256 totalSupply; // Total circulating supply of token;
        uint256 supplyCap; // Total supply of tokens that can exist (if isMintable == true, supplyCap == 0);
        bool isMintable; // Mintability: Token can be minted;
    }    

    /**
     * @dev Accesses the tokenIDs[] array
     *
     * note _index = tokenID - 1
     */
    function tokenIDs(uint256 _index) external view returns (TokenProps memory);

    /**
     * @dev Returns an array of all holders of a _tokenID
     */
    function tokenOwners(uint256 _tokenID) external view returns (address[] memory);

    /**
     * @dev Returns an _owner's index value in a tokenOwners[_tokenID] array.
     *
     * note Use this to know where inside a tokenOwners[_tokenID] array an _owner is.
     */
    function tokenOwnerIndex(address _owner, uint256 _tokenID) external view returns (uint256 index);

    /**
     * @dev Checks if _owner(s) own _tokenID(s). Three overloaded functions can take in any
     * number of tokenIDs and owner addresses that addresses three cases:
     *
     * Case 1: Caller needs to know if _owner holds _tokenID
     * Case 2: Caller needs to know if _owner holds any _tokenIDs
     * Case 3: Caller needs to know which _owners hold which _tokenIDs
     *
     * note The only reason to consider using these functions instead of balanceOf() is so the
     * front-end can receive a boolean as a response and not need to write additional logic
     * to compare numbers and make decisions. Just call ownsToken() and you'll know right away
     * if the address owns that token or not. Use these for token ownership gateways. If
     * calling balanceOf() from the front-end isn't too inconvenient, then we can remove these
     * getter functions entirely, or move them to an external utility contract.
     */
    //function ownsToken(uint256 _tokenID, address _owner) external view returns (bool);

    function ownsToken(uint256[] memory _tokenIDs, address _owner) external view returns (bool[] memory hasToken);

    //function ownsToken(uint256[] memory _tokenIDs, address[] memory _owners) external view returns (bool[][] memory hasTokens);

    /**
     * Performs an airdrop for three different cases:
     *
     * Case 1: An arbitrary list of _recipients will be transferred _amount of _tokenID
     * Case 2: An arbitrary list of _recipients will be transferred _amount of each _tokenIDs[i]
     * Case 3: _amount of _tokenToDrop will be transferred to all _recipients who own _tokenToCheck
     *
     * I chose to use Case 2, since it seems to be the most flexible, and I only have room for 1 function
     */
    //function airdropTokens(uint256 _tokenID, uint256 _amount, address[] memory _recipients) external returns (bool);

    function airdropTokens(uint256[] memory _tokenIDs, uint256[] memory _amounts, address[] memory _recipients) external returns (bool);

    //function airdropTokens(uint256 _tokenToDrop, uint256 _tokenToCheck, uint256 _amount) external returns (bool);


    /**
     * @dev Creates a new Pazari Token
     *
     * @param _newURI URL that points to item's public metadata
     * @param _isMintable Can tokens be minted? DEFAULT: True
     * @param _amount Amount of tokens to create
     * @param _supplyCap Maximum supply cap. DEFAULT: 0 (infinite supply)
     */
    function createNewToken(
         string memory _newURI,
         uint256 _amount,
         uint256 _supplyCap,
         bool _isMintable)
        external;

    /**
     * @dev Use this function for producing either ERC721-style collections of many unique tokens or for
     * uploading a whole collection of works with varying token amounts.
     *
     * See createNewToken() for description of parameters.
     */
    function batchCreateTokens(
         string[] memory _newURIs,
         bool[] calldata _isMintable,
         uint256[] calldata _amounts,
         uint256[] calldata _supplyCaps)
         external returns (bool);

    /**
     * @dev Mints more copies of an existing token (NOT NEEDED FOR MVP)
     *
     * If the token creator provided isMintable == false for createNewToken(), then 
     * this function will revert. This function is only for "standard edition" type
     * of files, and only for sellers who minted a few tokens.
     */
    function mint(
         address _mintTo, 
         uint256 _tokenID, 
         uint256 _amount, 
         string memory, 
         bytes memory) 
        external returns (bool);

    /**
     * @dev Updates token's URI, only contract owners may call
     */
    function setURI(string memory _newURI, uint256 _tokenID) external;



}