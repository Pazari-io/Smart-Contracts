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
import "../Dependencies/Context.sol";
import "../Dependencies/ERC165.sol";
import "../Marketplace/Marketplace.sol";

abstract contract Pazari1155 is Context, ERC165, IERC1155MetadataURI {
  using Address for address;

  // Mapping from token ID to account balances
  mapping(uint256 => mapping(address => uint256)) internal _balances;

  // Mapping from account to operator approvals
  mapping(address => mapping(address => bool)) internal _operatorApprovals;

  // Returns tokenHolder index value for an address and a tokenID
  // token owner's address => tokenID => tokenHolder[] index value
  // Used by burn() and burnBatch() to avoid looping over tokenHolder[] arrays
  mapping(address => mapping(uint256 => uint256)) public tokenHolderIndex;

  // Restricts access to sensitive functions to only the owner(s) of this contract
  // This is specified during deployment, and more owners can be added later
  mapping(address => bool) internal isOwner;

  // Public array of all TokenProps structs created
  // Newest tokenID is tokenProps.length
  TokenProps[] public tokenProps;

  /**
   * @dev Struct to track token properties.
   *
   * note I decided to include tokenID here since tokenID - 1 is needed for tokenProps[],
   * which may get confusing. We can use the tokenID property to double-check that we
   * are accessing the correct token's properties. It also looks and feels more intuitive
   * as well for a struct that tells us everything we need to know about a tokenID.
   */
  struct TokenProps {
    uint256 tokenID; // ID of token
    string uri; // IPFS URI where public metadata is located
    uint256 totalSupply; // Circulating/minted supply;
    uint256 supplyCap; // Max supply of tokens that can exist;
    bool isMintable; // Token can be minted;
    address[] tokenHolders; // All holders of this token, if fungible
  }

  /**
   * @param _contractOwners Array of all operators that do not require approval to handle
   * transferFrom() operations. Default is the Pazari Marketplace contract, but more operators
   * can be passed in. Operators are mostly responsible for minting new tokens.
   */
  constructor(address[] memory _contractOwners) {
    super;
    for (uint256 i = 0; i < _contractOwners.length; i++) {
      _operatorApprovals[_msgSender()][_contractOwners[i]] = true;
      isOwner[_contractOwners[i]] = true;
    }
  }

  /**
   * @dev Restricts access to the owner(s) of the contract
   */
  modifier onlyOwners() {
    require(isOwner[_msgSender()], "Only contract owners permitted");
    _;
  }

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
   * @dev External function that updates URI
   *
   * Only the contract owner(s) may update content URI
   */
  function setURI(string memory _newURI, uint256 _tokenID) external onlyOwners {
    _setURI(_newURI, _tokenID);
  }

  /**
   * @dev Internal function that updates URI;
   */
  function _setURI(string memory _newURI, uint256 _tokenID) internal {
    tokenProps[_tokenID - 1].uri = _newURI;
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
   * @dev Burns copies of a token from a token owner's address.
   *
   * This can be called by anyone, and if they burn all of their tokens then
   * their address in TokenProps.tokenHolders[] will be set to address(0). However,
   * their tokenHolderIndex[] value will not be deleted, as it will be used to
   * put them back on the list of tokenOwners if they receive another token.
   */
  function burn(uint256 _tokenID, uint256 _amount) external returns (bool) {
    _burn(_msgSender(), _tokenID, _amount);
    // After successful burn, if balanceOf == 0 then set tokenHolder address to address(0)
    if (balanceOf(_msgSender(), _tokenID) == 0) {
      tokenProps[_tokenID - 1].tokenHolders[tokenHolderIndex[_msgSender()][_tokenID]] = address(0);
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
        tokenProps[_tokenIDs[i] - 1].tokenHolders[tokenHolderIndex[_msgSender()][_tokenIDs[i]]] = address(0);
      }
    }
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

  /**
   * @notice Checks multiple tokenIDs against a single address and returns an array of bools
   * indicating ownership for each tokenID.
   *
   * @param _tokenIDs Array of tokenIDs to check ownership of
   * @param _owner Wallet address being checked
   *
   * @dev This seems like the most likely used function for token verification gimmicks. We
   * probably won't need a function that checks multiple addresses against multiple tokenIDs
   * for MVP, but I will create an external contract for these functions if we do.
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
   * @dev Hook that is called before any token transfer. This includes minting
   * and burning, as well as batched variants.
   *
   * The same hook is called on both single and batched variants. For single
   * transfers, the length of the `id` and `amount` arrays will be 1.
   *
   * Calling conditions (for each `id` and `amount` pair):
   *
   * - When `from` and `to` are both non-zero, `amount` of ``from``'s tokens
   * of token type `id` will be  transferred to `to`.
   * - When `from` is zero, `amount` tokens of token type `id` will be minted
   * for `to`.
   * - when `to` is zero, `amount` of ``from``'s tokens of token type `id`
   * will be burned.
   * - `from` and `to` are never both zero.
   * - `ids` and `amounts` have the same, non-zero length.
   *
   * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
   */
  function _beforeTokenTransfer(
    address,
    address,
    address to,
    uint256[] memory ids,
    uint256[] memory,
    bytes memory
  ) internal virtual {
    bool[] memory tempBools = ownsToken(ids, to);
    // If recipient does not own a token, then add their address to tokenHolders
    for (uint256 i = 0; i < ids.length; i++) {
      if (tempBools[i] == false) {
        tokenProps[ids[i] - 1].tokenHolders.push(to);
      }
    }
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
