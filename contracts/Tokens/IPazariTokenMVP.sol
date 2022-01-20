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
  // Fires when a new token is created through createNewToken()
  event TokenCreated(string URI, uint256 indexed tokenID, uint256 amount);

  // Fires when more tokens are minted from a pre-existing tokenID
  event TokensMinted(address indexed mintTo, uint256 indexed tokenID, uint256 amount);

  // Fires when tokens are transferred via airdropTokens()
  event TokensAirdropped(uint256 indexed tokenID, uint256 amount, uint256 timestamp);

  /**
   * @dev Struct to track token properties.
   */
  struct TokenProps {
    string uri; // IPFS URI where public metadata is located
    uint256 totalSupply; // Total circulating supply of token;
    uint256 supplyCap; // Total supply of tokens that can exist (if isMintable == true, supplyCap == 0);
    bool isMintable; // Mintability: Token can be minted;
  }

  //***FUNCTIONS: SETTERS***\\

  /**
   * @dev This implementation returns the URI stored for any _tokenID,
   * overwrites ERC1155's uri() function while maintaining compatibility
   * with OpenSea's standards.
   */
  function uri(uint256 _tokenID) external view override returns (string memory);

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
   * @notice Performs an airdrop for multiple tokens to many recipients
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

  //***FUNCTIONS: GETTERS***\\

  /**
   * @notice Checks multiple tokenIDs against a single address and returns an array of bools
   * indicating ownership for each tokenID.
   *
   * @param _tokenIDs Array of tokenIDs to check ownership of
   * @param _owner Wallet address being checked
   * @return bool[] Array of mappings where true means the _owner has at least one tokenID
   */
  function ownsToken(uint256[] memory _tokenIDs, address _owner) external view returns (bool[] memory);

  /**
   * @notice Returns TokenProps struct
   *
   * @dev Only available to token contract admins
   */
  function getTokenProps(uint256 tokenID) external view returns (TokenProps memory);

  /**
   * @notice Returns an array of all holders of a _tokenID
   *
   * @dev Only available to token contract admins
   */
  function getTokenHolders(uint256 _tokenID) external view returns (address[] memory);

  /**
   * @notice Returns tokenHolderIndex value for an address and a tokenID
   * @dev All this does is returns the location of an address inside a tokenID's tokenHolders
   */
  function getTokenHolderIndex(address _tokenHolder, uint256 _tokenID) external view returns (uint256);
}

interface IAccessControlPTMVP {
  // Accesses isAdmin mapping
  function isAdmin(address _adminAddress) external view returns (bool);

  /**
   * @notice Returns tx.origin for any Pazari-owned admin contracts, returns msg.sender
   * for everything else. See PaymentRouter for more details.
   */
  function _msgSender() external view returns (address);

  // Adds an address to isAdmin mapping
  function addAdmin(address _newAddress) external returns (bool);

  // Removes an address from isAdmin mapping
  function removeAdmin(address _oldAddress) external returns (bool);
}
