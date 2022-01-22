/**
 * @title PazariTokenMVP - Version: 0.1.0
 *
 * @dev Modification of the standard ERC1155 token contract for use
 * on the Pazari digital marketplace. These are one-time-payment
 * tokens, and are used for ownership verification after a file
 * has been purchased.
 *
 * Pazari uses ERC1155 tokens so it can possess immediate support
 * for ERC1155 NFTs, and the PazariToken is a modified ERC1155
 * with limited transfer capabilities.
 */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Dependencies/IERC1155.sol";
import "../Dependencies/IERC1155Receiver.sol";
import "../Dependencies/IERC1155MetadataURI.sol";
import "../Dependencies/Address.sol";
import "../Dependencies/ERC165.sol";
import "../Dependencies/Ownable.sol";
import "../Marketplace/Marketplace.sol";
import "./IPazariTokenMVP.sol";
import "./Pazari1155.sol";

contract PazariTokenMVP is Pazari1155 {
  using Address for address;

  // Fires when a new token is created through createNewToken()
  event TokenCreated(string URI, uint256 indexed tokenID, uint256 amount);

  // Fires when more tokens are minted from a pre-existing tokenID
  event TokensMinted(address indexed mintTo, uint256 indexed tokenID, uint256 amount);

  // Fires when tokens are transferred via airdropTokens()
  event TokensAirdropped(uint256 indexed tokenID, uint256 amount, uint256 timestamp);

  /**
   * @param _contractOwners Array of all addresses that have operator approval and
   * isAdmin status.
   */
  constructor(address[] memory _contractOwners) Pazari1155(_contractOwners) {}

  /**
   * @notice Returns TokenProps struct, only admins can call
   */
  function getTokenProps(uint256 _tokenID) public view onlyAdmin returns (TokenProps memory) {
    return tokenProps[_tokenID - 1];
  }

  /**
   * Returns tokenHolders array for tokenID, only admins can call
   */
  function getTokenHolders(uint256 _tokenID) public view onlyAdmin returns (address[] memory) {
    return tokenHolders[_tokenID];
  }

  /**
   * @notice Returns tokenHolderIndex value for an address and a tokenID
   * @dev All this does is returns the location of an address inside a tokenID's tokenHolders
   */
  function getTokenHolderIndex(address _tokenHolder, uint256 _tokenID)
    public
    view
    onlyAdmin
    returns (uint256)
  {
    return tokenHolderIndex[_tokenHolder][_tokenID];
  }

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
    bool _isMintable
  ) external onlyAdmin returns (uint256) {
    uint256 tokenID;
    // If _amount == 0, then supply is infinite
    if (_amount == 0) {
      _amount = type(uint256).max;
    }
    // If _supplyCap > 0, then require _amount <= _supplyCap
    if (_supplyCap > 0) {
      require(_amount <= _supplyCap, "Amount exceeds supply cap");
    }
    // If _supplyCap == 0, then set _supplyCap to max value
    else {
      _supplyCap = type(uint256).max;
    }

    tokenID = _createToken(_newURI, _isMintable, _amount, _supplyCap);
    return tokenID;
  }

  function _createToken(
    string memory _newURI,
    bool _isMintable,
    uint256 _amount,
    uint256 _supplyCap
  ) internal returns (uint256 tokenID) {
    // The zeroth tokenHolder is address(0)
    tokenHolderIndex[address(0)][tokenID] = 0;
    tokenHolders[tokenID].push(address(0));

    tokenID = tokenProps.length;
    // Create new TokenProps and push to tokenProps array
    TokenProps memory newToken = TokenProps(tokenProps.length, _newURI, _amount, _supplyCap, _isMintable);
    tokenProps.push(newToken);
    // Grab tokenID from newToken's struct
    tokenID = newToken.tokenID;

    // Mint tokens to _msgSender()
    require(_mint(_msgSender(), tokenID, _amount, ""), "Minting failed");

    emit TokenCreated(_newURI, tokenID, _amount);
  }

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
  ) external onlyAdmin returns (bool) {
    // Check that all arrays are same length
    require(
      _newURIs.length == _isMintable.length &&
        _isMintable.length == _amounts.length &&
        _amounts.length == _supplyCaps.length,
      "Data fields must have same length"
    );

    // Iterate through input arrays, create new token on each iteration
    for (uint256 i = 0; i <= _newURIs.length; i++) {
      string memory newURI = _newURIs[i];
      bool isMintable_ = _isMintable[i];
      uint256 amount = _amounts[i];
      uint256 supplyCap = _supplyCaps[i];

      _createToken(newURI, isMintable_, amount, supplyCap);
    }
    return true;
  }

  /**
   * @notice Mints more units of a created token
   *
   * @dev Only available for tokens with isMintable == true
   *
   * @param _mintTo Address tokens were minted to (MVP: msg.sender)
   * @param _tokenID Token ID being minted
   * @param _amount Amount of tokenID to be minted
   * @return Bool Success bool
   *
   * @dev Emits TokensMinted event
   */
  function mint(
    address _mintTo,
    uint256 _tokenID,
    uint256 _amount,
    string memory,
    bytes memory
  ) external onlyAdmin returns (bool) {
    TokenProps memory tokenProperties = tokenProps[_tokenID - 1];
    require(tokenProperties.totalSupply > 0, "Token does not exist");
    require(tokenProps[_tokenID - 1].isMintable, "Minting disabled");
    if (tokenProperties.supplyCap != 0) {
      // Check that new amount does not exceed the supply cap
      require(tokenProperties.totalSupply + _amount <= tokenProperties.supplyCap, "Amount exceeds cap");
    }
    _mint(_mintTo, _tokenID, _amount, "");
    emit TokensMinted(_mintTo, _tokenID, _amount);
    return true;
  }

  /**
   * @dev Performs a multi-token airdrop of each _amounts[i] for each _[i] to each _recipients[j]
   *
   * @param _tokenIDs Tokens being airdropped
   * @param _amounts Amount of each token being sent to each recipient
   * @param _recipients All airdrop recipients
   * @return Success bool
   */
  function airdropTokens(
    uint256[] memory _tokenIDs,
    uint256[] memory _amounts,
    address[] memory _recipients
  ) external onlyAdmin returns (bool) {
    require(_amounts.length == _tokenIDs.length, "Amounts and tokenIds must be same length");
    uint256 i; // TokenID and amount counter
    uint256 j; // Recipients counter
    // Iterate through each tokenID being airdropped:
    for (i = 0; i < _tokenIDs.length; i++) {
      require(balanceOf(_msgSender(), _tokenIDs[i]) >= _recipients.length, "Not enough tokens for airdrop");
      // Iterate through recipients, transfer tokenID if recipient != address(0)
      // See burn() for why some addresses in tokenHolders may be address(0)
      for (j = 0; j < _recipients.length; j++) {
        if (_recipients[j] == address(0)) continue;
        // If found, then skip address(0)
        else _safeTransferFrom(_msgSender(), _recipients[j], _tokenIDs[i], _amounts[i], "");
      }
    }
    return true;
  }

  /**
   * @dev Overridden ERC1155 function, requires that the caller of the function
   * is an owner of the contract.
   *
   * @dev Transfers should only work for isAdmin => isAdmin and for isAdmin => !isAdmin,
   * but not for !isAdmin => !isAdmin. Only admins are allowed to transfer these tokens
   * to non-admins.
   *
   * @dev The logic gives instruction for when recipient is not admin but sender is, which
   * is permitted freely. This is like a store selling an item to someone. What is also
   * implied by this condition is that it is acceptable for recipients to transfer their
   * PazariTokens back to the sender/admin, which would happen during a refund. What is
   * also implied is that it is not acceptable for recipients to transfer their PazariTokens
   * to anyone else. These tokens are attached to downloadable content, and should NOT be
   * transferrable to non-admin addresses to protect the content.
   */
  function safeTransferFrom(
    address from,
    address to,
    uint256 id,
    uint256 amount,
    bytes memory data
  ) external virtual override {
    // If recipient is not admin, then sender needs to be admin
    if (!isAdmin[to]) {
      require(isAdmin[from], "PazariToken: Only admins may send PazariTokens to non-admins");
    }
    _safeTransferFrom(from, to, id, amount, data);
  }

  /**
   * @dev This implementation returns the URI stored for any _tokenID,
   * overwrites ERC1155's uri() function while maintaining compatibility
   * with OpenSea's standards.
   */
  function uri(uint256 _tokenID) public view virtual override returns (string memory) {
    return tokenProps[_tokenID - 1].uri;
  }
}
