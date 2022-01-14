/**
 * @title Pazari1155
 *
 * @dev This is the ERC1155 contract that PazariTokens are made from. All ERC1155-native
 * functions are here, as well as Pazari-native functions that are essential.
 */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Dependencies/IERC1155MetadataURI.sol";
import "../Dependencies/Address.sol";
import "../Dependencies/ERC165.sol";
import "../Marketplace/Marketplace.sol";

contract AccessControlPTMVP {
  // Maps admin addresses to bool
  // These are NOT Pazari developer admins, but can include Pazari helpers
  mapping(address => bool) public isAdmin;

  // The address that cloned this contract, never loses admin access
  address internal immutable originalOwner;

  constructor(address[] memory _adminAddresses) {
    for (uint256 i = 0; i < _adminAddresses.length; i++) {
      isAdmin[_adminAddresses[i]] = true;
    }
    originalOwner = _msgSender();
  }

  modifier onlyAdmin() {
    require(isAdmin[_msgSender()], "Caller is not admin");
    _;
  }

  /**
   * @notice Returns tx.origin for any Pazari-owned admin contracts, returns msg.sender
   * for everything else. This only permits Pazari helper contracts to use tx.origin,
   * and all external non-admin contracts and wallets will use msg.sender.
   * @dev This design is vulnerable to phishing attacks if a helper contract that
   * has isAdmin does NOT implement the same _msgSender() logic.
   * @dev _msgSender()'s context is the contract it is being called from, and uses
   * that contract's AccessControl storage for isAdmin. External contracts can use
   * each other's _msgSender() for if they need to use the same AccessControl storage.
   */
  function _msgSender() public view returns (address) {
    if (tx.origin != msg.sender && isAdmin[msg.sender]) {
      return tx.origin;
    } else return msg.sender;
  }

  // Adds an address to isAdmin mapping
  // Requires both tx.origin and msg.sender be admins
  function addAdmin(address _newAddress) external returns (bool) {
    require(isAdmin[msg.sender] && isAdmin[tx.origin], "Caller is not admin");
    require(!isAdmin[_newAddress], "Address is already an admin");
    isAdmin[_newAddress] = true;
    return true;
  }

  // Removes an address from isAdmin mapping
  // Requires both tx.origin and msg.sender be admins
  function removeAdmin(address _oldAddress) external returns (bool) {
    require(isAdmin[msg.sender] && isAdmin[tx.origin], "Caller is not admin");
    require(_oldAddress != originalOwner, "Cannot remove original owner");
    require(isAdmin[_oldAddress], "Address must be an admin");
    isAdmin[_oldAddress] = false;
    return true;
  }
}

abstract contract Pazari1155 is AccessControlPTMVP, ERC165, IERC1155MetadataURI {
  using Address for address;

  // Mapping from token ID to account balances
  mapping(uint256 => mapping(address => uint256)) internal _balances;

  // Mapping from account to operator approvals
  mapping(address => mapping(address => bool)) internal _operatorApprovals;

  // Returns tokenHolder index value for an address and a tokenID
  // token owner's address => tokenID => tokenHolder[index] value
  mapping(address => mapping(uint256 => uint256)) public tokenHolderIndex;

  // Maps tokenIDs to tokenHolders arrays
  mapping(uint256 => address[]) internal tokenHolders;

  // Public array of all TokenProps structs created
  TokenProps[] public tokenProps;

  /**
   * @dev Struct to track token properties.
   */
  struct TokenProps {
    uint256 tokenID; // ID of token
    string uri; // IPFS URI where public metadata is located
    uint256 totalSupply; // Circulating/minted supply;
    uint256 supplyCap; // Max supply of tokens that can exist;
    bool isMintable; // Token can be minted;
  }

  /**
   * @param _contractOwners Array of all operators that do not require approval to handle
   * transferFrom() operations and have isAdmin status. Initially, these addresses will
   * only include the contract creator's wallet address (if using PazariMVP), and the
   * addresses for Marketplace and PazariMVP. If contract creator was not using PazariMVP
   * or any kind of isAdmin contract, then _contractOwners will include the contract's
   * address instead of the user's wallet address. This is intentional for use with
   * multi-sig contracts later.
   */
  constructor(address[] memory _contractOwners) AccessControlPTMVP(_contractOwners) {
    super;
    for (uint256 i = 0; i < _contractOwners.length; i++) {
      _operatorApprovals[_msgSender()][_contractOwners[i]] = true;
    }
  }

  //***FUNCTIONS: ERC1155 MODIFIED & PAZARI***\\

  /**
   * @notice Checks multiple tokenIDs against a single address and returns an array of bools
   * indicating ownership for each tokenID.
   *
   * @param _tokenIDs Array of tokenIDs to check ownership of
   * @param _owner Wallet address being checked
   */
  function ownsToken(uint256[] memory _tokenIDs, address _owner) public view returns (bool[] memory) {
    bool[] memory hasToken = new bool[](_tokenIDs.length);

    for (uint256 i = 0; i < _tokenIDs.length; i++) {
      uint256 tokenID = _tokenIDs[i];
      if (balanceOf(_owner, tokenID) != 0) {
        hasToken[i] = true;
      } else {
        hasToken[i] = false;
      }
    }
    return hasToken;
  }

  /**
   * @dev External function that updates URI
   *
   * Only contract admins may update content URI
   */
  function setURI(string memory _newURI, uint256 _tokenID) external onlyAdmin {
    _setURI(_newURI, _tokenID);
  }

  /**
   * @dev Internal function that updates URI;
   */
  function _setURI(string memory _newURI, uint256 _tokenID) internal {
    tokenProps[_tokenID - 1].uri = _newURI;
  }

  /**
   * @notice Burns copies of a token from a token owner's address.
   *
   * @dev When an address has burned all of their tokens their address in
   * that tokenID's tokenHolders array is set to address(0). However, their
   * tokenHoldersIndex mapping is not removed, and can be used for checks.
   */
  function burn(uint256 _tokenID, uint256 _amount) external returns (bool) {
    _burn(_msgSender(), _tokenID, _amount);
    // After successful burn, if balanceOf == 0 then set tokenHolder address to address(0)
    if (balanceOf(_msgSender(), _tokenID) == 0) {
      tokenHolders[_tokenID][tokenHolderIndex[_msgSender()][_tokenID]] = address(0);
    }
    return true;
  }

  /**
   * @dev Burns a batch of tokens from the caller's address.
   *
   * This can be called by anyone, and if they burn all of their tokens then
   * their address in tokenOwners[tokenID] will be set to address(0). However,
   * their tokenHolderIndex value will not be deleted, as it will be used to
   * put them back on the list of tokenOwners if they receive another token.
   */
  function burnBatch(uint256[] calldata _tokenIDs, uint256[] calldata _amounts) external returns (bool) {
    _burnBatch(_msgSender(), _tokenIDs, _amounts);
    for (uint256 i = 0; i < _tokenIDs.length; i++) {
      if (balanceOf(_msgSender(), _tokenIDs[i]) == 0) {
        tokenHolders[_tokenIDs[i]][tokenHolderIndex[_msgSender()][_tokenIDs[i]]] = address(0);
      }
    }
    return true;
  }

  /**
   * @dev Hook that is called before any token transfer. This includes minting
   * and burning, as well as batched variants.
   *
   * @dev Pazari's variant checks to see if a recipient owns any tokens already,
   * and if not then their address is added to a tokenHolders array. If they were
   * previously a tokenHolder but burned all their tokens then their address is
   * added back in to the token's tokenHolders array.
   */
  function _beforeTokenTransfer(
    address,
    address,
    address recipient,
    uint256[] memory tokenIDs,
    uint256[] memory,
    bytes memory
  ) internal virtual {
    // Get an array of bools for which tokenIDs recipient owns
    bool[] memory hasTokens = ownsToken(tokenIDs, recipient);
    // Iterate through array
    for (uint256 i = 0; i < tokenIDs.length; i++) {
      if (hasTokens[i] == false) {
        // Run logic if recipient does not own a token
        // If recipient was a tokenHolder before, then put them back in tokenHolders
        if (tokenHolderIndex[recipient][tokenIDs[i]] != 0) {
          tokenHolders[tokenIDs[i]][tokenHolderIndex[recipient][tokenIDs[i]]] = recipient;
        }
        // if not, then push recipient's address to tokenHolders
        else tokenHolders[tokenIDs[i]].push(recipient);
      }
    }
  }

  //***FUNCTIONS: ERC1155 UNMODIFIED***\\

  /**
   * @dev See {IERC165-supportsInterface}.
   */
  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC165, IERC165)
    returns (bool)
  {
    return
      interfaceId == type(IERC1155).interfaceId ||
      interfaceId == type(IERC1155MetadataURI).interfaceId ||
      super.supportsInterface(interfaceId);
  }

  /**
   * @dev See {IERC1155-balanceOf}.
   *
   * Requirements:
   *
   * - `account` cannot be the zero address.
   */
  function balanceOf(address account, uint256 id) public view virtual override returns (uint256) {
    require(account != address(0), "ERC1155: balance query for the zero address");
    return _balances[id][account];
  }

  /**
   * @dev See {IERC1155-balanceOfBatch}.
   *
   * Requirements:
   *
   * - `accounts` and `ids` must have the same length.
   */
  function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
    public
    view
    virtual
    override
    returns (uint256[] memory)
  {
    require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");

    uint256[] memory batchBalances = new uint256[](accounts.length);

    for (uint256 i = 0; i < accounts.length; ++i) {
      batchBalances[i] = balanceOf(accounts[i], ids[i]);
    }

    return batchBalances;
  }

  /**
   * @dev See {IERC1155-setApprovalForAll}.
   */
  function setApprovalForAll(address operator, bool approved) public virtual override {
    require(_msgSender() != operator, "ERC1155: setting approval status for self");

    _operatorApprovals[_msgSender()][operator] = approved;
    emit ApprovalForAll(_msgSender(), operator, approved);
  }

  /**
   * @dev See {IERC1155-isApprovedForAll}.
   */
  function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
    return _operatorApprovals[account][operator];
  }

  /**
   * @dev See {IERC1155-safeBatchTransferFrom}.
   */
  function safeBatchTransferFrom(
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
  ) public virtual override {
    require(
      from == _msgSender() || isApprovedForAll(from, _msgSender()),
      "ERC1155: transfer caller is not creator nor approved"
    );
    // Require caller is an admin
    // If caller is a contract with isAdmin, then user's wallet address is checked
    // If caller is a contract without isAdmin, then contract's address is checked instead
    require(isAdmin[_msgSender()], "PazariToken: Caller is not admin");
    // If recipient is not admin, then sender needs to be admin
    if (!isAdmin[to]) {
      require(isAdmin[from], "PazariToken: Only admins may transfer");
    }

    _safeBatchTransferFrom(from, to, ids, amounts, data);
  }

  /**
   * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
   *
   * Emits a {TransferSingle} event.
   *
   * Requirements:
   *
   * - `to` cannot be the zero address.
   * - `from` must have a balance of tokens of type `id` of at least `amount`.
   * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
   * acceptance magic value.
   */
  function _safeTransferFrom(
    address from,
    address to,
    uint256 id,
    uint256 amount,
    bytes memory data
  ) internal virtual {
    require(to != address(0), "ERC1155: transfer to the zero address");

    address operator = _msgSender();

    _beforeTokenTransfer(operator, from, to, _asSingletonArray(id), _asSingletonArray(amount), data);

    uint256 fromBalance = _balances[id][from];
    require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
    _balances[id][from] = fromBalance - amount;
    _balances[id][to] += amount;

    emit TransferSingle(operator, from, to, id, amount);

    _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
  }

  /**
   * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_safeTransferFrom}.
   *
   * Emits a {TransferBatch} event.
   *
   * Requirements:
   *
   * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
   * acceptance magic value.
   */
  function _safeBatchTransferFrom(
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
  ) internal virtual {
    require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
    require(to != address(0), "ERC1155: transfer to the zero address");

    address operator = _msgSender();

    _beforeTokenTransfer(operator, from, to, ids, amounts, data);

    for (uint256 i = 0; i < ids.length; ++i) {
      uint256 id = ids[i];
      uint256 amount = amounts[i];

      uint256 fromBalance = _balances[id][from];
      require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
      _balances[id][from] = fromBalance - amount;
      _balances[id][to] += amount;
    }

    emit TransferBatch(operator, from, to, ids, amounts);

    _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts, data);
  }

  /**
   * @dev Creates `amount` tokens of token type `id`, and assigns them to `account`.
   *
   * Emits a {TransferSingle} event.
   *
   * Requirements:
   *
   * - `account` cannot be the zero address.
   * - If `account` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
   * acceptance magic value.
   */
  function _mint(
    address account,
    uint256 id,
    uint256 amount,
    bytes memory data
  ) internal virtual returns (bool) {
    require(account != address(0), "ERC1155: mint to the zero address");

    address operator = _msgSender();

    //_beforeTokenTransfer(operator, address(0), account, _asSingletonArray(id), _asSingletonArray(amount), data);

    _balances[id][account] += amount;
    emit TransferSingle(operator, address(0), account, id, amount);

    _doSafeTransferAcceptanceCheck(operator, address(0), account, id, amount, data);
    return true;
  }

  /**
   * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_mint}.
   *
   * Requirements:
   *
   * - `ids` and `amounts` must have the same length.
   * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
   * acceptance magic value.
   */
  function _mintBatch(
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
  ) internal virtual returns (bool) {
    require(to != address(0), "ERC1155: mint to the zero address");
    require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

    address operator = _msgSender();

    _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

    for (uint256 i = 0; i < ids.length; i++) {
      _balances[ids[i]][to] += amounts[i];
    }

    emit TransferBatch(operator, address(0), to, ids, amounts);

    _doSafeBatchTransferAcceptanceCheck(operator, address(0), to, ids, amounts, data);
    return true;
  }

  /**
   * @dev Destroys `amount` tokens of token type `id` from `account`
   *
   * Requirements:
   *
   * - `account` cannot be the zero address.
   * - `account` must have at least `amount` tokens of token type `id`.
   */
  function _burn(
    address account,
    uint256 id,
    uint256 amount
  ) internal virtual returns (bool) {
    require(account != address(0), "ERC1155: burn from the zero address");

    address operator = _msgSender();

    _beforeTokenTransfer(operator, account, address(0), _asSingletonArray(id), _asSingletonArray(amount), "");

    uint256 accountBalance = _balances[id][account];
    require(accountBalance >= amount, "ERC1155: burn amount exceeds balance");
    _balances[id][account] = accountBalance - amount;

    emit TransferSingle(operator, account, address(0), id, amount);
    return true;
  }

  /**
   * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_burn}.
   *
   * Requirements:
   *
   * - `ids` and `amounts` must have the same length.
   */
  function _burnBatch(
    address account,
    uint256[] memory ids,
    uint256[] memory amounts
  ) internal virtual returns (bool) {
    require(account != address(0), "ERC1155: burn from the zero address");
    require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

    address operator = _msgSender();

    _beforeTokenTransfer(operator, account, address(0), ids, amounts, "");

    for (uint256 i = 0; i < ids.length; i++) {
      uint256 id = ids[i];
      uint256 amount = amounts[i];

      uint256 accountBalance = _balances[id][account];
      require(accountBalance >= amount, "ERC1155: burn amount exceeds balance");
      _balances[id][account] = accountBalance - amount;
    }

    emit TransferBatch(operator, account, address(0), ids, amounts);
    return true;
  }

  function _doSafeTransferAcceptanceCheck(
    address operator,
    address from,
    address to,
    uint256 id,
    uint256 amount,
    bytes memory data
  ) private {
    if (to.isContract()) {
      try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
        if (response != IERC1155Receiver(to).onERC1155Received.selector) {
          revert("ERC1155: ERC1155Receiver rejected tokens");
        }
      } catch Error(string memory reason) {
        revert(reason);
      } catch {
        revert("ERC1155: transfer to non ERC1155Receiver implementer");
      }
    }
  }

  function _doSafeBatchTransferAcceptanceCheck(
    address operator,
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
  ) private {
    if (to.isContract()) {
      try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (
        bytes4 response
      ) {
        if (response != IERC1155Receiver(to).onERC1155BatchReceived.selector) {
          revert("ERC1155: ERC1155Receiver rejected tokens");
        }
      } catch Error(string memory reason) {
        revert(reason);
      } catch {
        revert("ERC1155: transfer to non ERC1155Receiver implementer");
      }
    }
  }

  function _asSingletonArray(uint256 element) private pure returns (uint256[] memory) {
    uint256[] memory array = new uint256[](1);
    array[0] = element;

    return array;
  }
}
