/**
 * @dev Interface for interacting with any PazariTokenMVP contract.
 *
 * Inherits from IERC1155MetadataURI, therefore all IERC1155 function
 * calls will work on a Pazari token. The IPazariTokenMVP interface
 * accesses the Pazari-specific functions of a Pazari token.
 *
 * Version 0.1.2:
 * - Added tokenID as a return value for createNewToken()
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Dependencies/IERC1155MetadataURI.sol";

interface IPazariTokenMVP is IERC1155MetadataURI {
  // Fires when a recipient receives a tokenID from the airdropTokens() function
  event TokenAirdropped(uint256 indexed tokenID, uint256 amount, address indexed recipient);

  // Fires when a new token is created through createNewToken()
  event TokenCreated(string URI, uint256 indexed tokenID, uint256 amount);

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
  function tokenHolders(uint256 _tokenID) external view returns (address[] memory);

  /**
   * @notice Returns an address's index value in a token's tokenHolders[] array property.
   *
   * @dev Not really needed for front-end. This is just a mapping that tells you where an address
   * is inside a token's tokenHolders[] array. If it returns 0, then that address is not a holder,
   * since tokenHolders[0] == address(0) for all tokens.
   */
  function tokenHolderIndex(address _owner, uint256 _tokenID) external view returns (uint256 index);

  /**
   * @notice Performs an airdrop for multiple tokens to many recipients
   *
   * @dev NOT USED FOR MVP
   *
   * @param _tokenIDs Array of all tokenIDs being airdropped
   * @param _amounts Array of all amounts of each tokenID to drop to each recipient
   * @param _recipients Array of all recipients for the airdrop
   *
   * @dev Emits TokenAirdropped event
   */
  function airdropTokens(
    uint256[] memory _tokenIDs,
    uint256[] memory _amounts,
    address[] memory _recipients
  ) external returns (bool);

  /**
   * @dev Creates a new Pazari Token
   *
   * @param _newURI URL that points to item's public metadata
   * @param _isMintable Can tokens be minted? DEFAULT: True
   * @param _amount Amount of tokens to create
   * @param _supplyCap Maximum supply cap. DEFAULT: 0 (infinite supply)
   * @return uint256 TokenID of new token
   */
  function createNewToken(
    string memory _newURI,
    uint256 _amount,
    uint256 _supplyCap,
    bool _isMintable
  ) external returns (uint256);

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
    uint256[] calldata _supplyCaps
  ) external returns (bool);

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
    bytes memory
  ) external returns (bool);

  /**
   * @dev Burns _amount copies of a _tokenID (NOT NEEDED FOR MVP)
   */
  function burn(uint256 _tokenID, uint256 _amount) external returns (bool);

  /**
   * @dev Burns multiple tokenIDs
   */
  function burnBatch(uint256[] calldata _tokenIDs, uint256[] calldata _amounts) external returns (bool);

  /**
   * @dev Updates token's URI, only contract owners may call
   */
  function setURI(string memory _newURI, uint256 _tokenID) external;

  /**
   * @notice Adds new owner addresses, only owners can call
   *
   * @dev Emits OwnerAdded event for each address added
   *
   * @dev Owners can pass the onlyOwners modifier, so be careful with who we add.
   * This function is intended as a backdoor so we can add new smart contracts in
   * the future that can access restricted functions, while also eliminating
   * operator approval for transferFrom(). This exposes some obvious attack
   * vectors that need to be avoided when/if this function is implemented on
   * the front-end.
   */
  function addOwners(address[] memory _newOwners) external;

  /**
   * @notice Checks multiple tokenIDs against a single address and returns an array of bools
   * indicating ownership for each tokenID.
   *
   * @param _tokenIDs Array of tokenIDs to check ownership of
   * @param _owner Wallet address being checked
   */
  function ownsToken(uint256[] memory _tokenIDs, address _owner) external view returns (bool[] memory);

  // Not sure if we need this or not
  function supportsInterface(bytes4 interfaceId) external view override returns (bool);
}
