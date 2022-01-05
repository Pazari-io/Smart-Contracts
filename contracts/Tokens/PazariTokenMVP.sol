/**
 * @title PazariTokenMVP - Version: 0.1.0
 *
 * @dev Modification of the standard ERC1155 token contract for use
 * on the Pazari digital marketplace. These are one-time-payment
 * tokens, and are used for ownership verification after a file
 * has been purchased.
 *
 * Because these are 1155 tokens, creators can mint fungible and
 * non-fungible tokens, depending upon the item they wish to sell.
 * However, they are not transferrable to anyone who isn't an 
 * owner of the contract. These tokens are pseudo-NFTs.
 *
 * TokenIDs start at 1 instead of 0. TokenID 0 can be used for
 * existence checking.
 *
 * All tokenHolders are tracked inside of each tokenID's TokenProps,
 * which makes airdrops much easier to accommodate.
 *
 * For ownsToken() and airdropToken() I created three overloaded
 * designs for these functions. We can only use one design of each
 * function due to contract size limits in the factory.
 * - I intend to move the airdropping functionality to a new
 *   utility contract that can be cloned by sellers who wish
 *   to use it. This contract is already on the edge of its
 *   size limits, so we need to figure out which functions
 *   can be offloaded to an external contract before we
 *   deploy the official MVP.
 */

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../Dependencies/IERC1155.sol";
import "../Dependencies/IERC1155Receiver.sol";
import "../Dependencies/IERC1155MetadataURI.sol";
import "../Dependencies/Address.sol";
import "../Dependencies/Context.sol";
import "../Dependencies/ERC165.sol";
import "../Dependencies/Ownable.sol";
import "../Marketplace/Marketplace.sol";
import "./IPazariTokenMVP.sol";

contract PazariTokenMVP is Context, ERC165, IERC1155MetadataURI {
    using Address for address;

    // Mapping from token ID to account balances
    mapping (uint256 => mapping(address => uint256)) private _balances;

    // Mapping from account to operator approvals
    mapping (address => mapping(address => bool)) private _operatorApprovals;

    // Restricts access to sensitive functions to only the owner(s) of this contract
     // This is specified during deployment, and more owners can be added later
    mapping(address => bool) private isOwner;

    // Returns tokenOwner index value for an address and a tokenID
     // token owner's address => tokenID => tokenOwner[] index value
     // Used by burn() and burnBatch() to avoid looping over tokenOwner[] arrays
    mapping(address => mapping(uint256 => uint256)) public tokenOwnerIndex;

    // Public array of all TokenProps structs created
     // Newest tokenID is tokenIDs.length
    TokenProps[] public tokenIDs;

    /**
     * @dev Struct to track token properties.
     *
     * note I decided to include tokenID here since tokenID - 1 is needed for tokenIDs[],
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
    constructor (address[] memory _contractOwners) {
        super;
        for (uint i = 0; i < _contractOwners.length; i++) {
            _operatorApprovals[_msgSender()][_contractOwners[i]] = true;
            isOwner[_contractOwners[i]] = true;
        }
    }

    /**
     * @dev Checks if _tokenID is mintable or not:
     * True = Standard Edition, can be minted -- supplyCap == 0 (DEFAULT)
     * False = Limited Edition, cannot be minted -- supplyCap >= totalSupply
     */
    modifier isMintable(uint256 _tokenID) {
        require(tokenIDs[_tokenID - 1].isMintable, "Minting disabled");
        _;
    }

    /**
     * @dev Restricts access to the owner(s) of the contract
     */
    modifier onlyOwners() {
        require(isOwner[msg.sender], "Only contract owners permitted");
        _;
    }

    /**
     * @dev Adds a new owner address, only owners can call
     */
    function addOwner(address _newOwner) external onlyOwners {
        _operatorApprovals[msg.sender][_newOwner] = true;
        isOwner[_newOwner] = true;        
    }

    /**
     * @dev Checks if user owns _tokenID.
     *
     * This function is intended for the front-end to determine when to permit downloads and
     * streaming services, and can be called by anyone. Returns a bool of whether or not the 
     * _owner owns the _tokenID.
     *
     * @param _tokenID TokenID being checked
     * @param _owner Address being checked
     */
/*
    function ownsToken(uint256 _tokenID, address _owner) public view returns (bool hasToken) {
        if (balanceOf(_owner, _tokenID) != 0) {
            hasToken = true;
        }
        else hasToken = false;
    }
*/
    /**
     * @dev Overloaded version of ownsToken(), checks multiple tokenIDs against a single address and
     * returns an array of bools indicating ownership for each _tokenID[i].
     *
     * @param _tokenIDs Array of tokenIDs to check ownership of
     * @param _owner Wallet address being checked
     *
     * This function is intended for use on sellers' websites in the future, when they can copy some
     * boilerplate code from us to use for creating a "Connect Wallet" button that will check for
     * token ownership across a range of _tokenIDs for whoever connects their wallet.
     */

    function ownsToken(uint256[] memory _tokenIDs, address _owner) public view returns (bool[] memory hasToken) {
        for(uint i = 0; i < _tokenIDs.length; i++){
            uint256 tokenID = _tokenIDs[i];       
            if (balanceOf(_owner, tokenID) != 0) {
                 hasToken[i] = true;
            }
            else hasToken[i] = false; 
        }
    }

    /**
     * @dev Overloaded version of ownsToken(), checks multiple tokenIDs against multiple owners. Returns
     * an array of arrays. Each element in the outer array is a bool array for _tokenIDs[i], and each
     * element in an inner array is a bool for each _owners[j] indicating ownership of _tokenIDs[i].
     *
     * @param _tokenIDs Array of all tokenIDs being checked
     * @param _owners Array of all addresses being checked
     * @return hasTokens Array of arrays indicating if each address owns each tokenID
     *
     * This may not ever be needed, I'm including it in case it is useful.
     *
     * note Since this is a view function, we can get away with using a double-loop pattern. This
     * function should NEVER be called by another contract though, it will most likely run out of gas!
     */
/*
    function ownsToken(uint256[] memory _tokenIDs, address[] memory _owners) public view returns (bool[][] memory hasTokens) {
        // Declare local variables for outer loop
        uint i; // Counter for _tokenIDs
        hasTokens = new bool[][](_tokenIDs.length);

        // Assemble outer array
        for(i = 0; i < _tokenIDs.length; i++){
            // Declare local variables for inner loop
            uint j; // Counter for _owners
            uint256 tokenID = _tokenIDs[i];
            bool[] memory tempBools = new bool[](_owners.length);
        
            // Assemble inner array
            for(j = 0; j < _owners.length; i++){
                address owner = _owners[j];
                if (balanceOf(owner, tokenID) != 0) {
                    tempBools[j] = true;
                }
                else tempBools[j] = false;
            }
            hasTokens[i] = tempBools;
        }
    }
*/
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
        external
        onlyOwners {
            // If _amount == 0, then supply is infinite
            if(_amount == 0) {
                _amount = type(uint256).max;
            }
            // If _supplyCap > 0, then require _amount <= _supplyCap
            if(_supplyCap > 0) {
                require(_amount <= _supplyCap, "Amount exceeds supply cap");
            }
            // If _supplyCap == 0, then set _supplyCap to max value
            else {
                _supplyCap = type(uint256).max;
            }

            _createToken(
                _newURI, 
                _isMintable,
                _amount,
                _supplyCap
            );            
    }

    function _createToken(
        string memory _newURI, 
        bool _isMintable,
        uint256 _amount,
        uint256 _supplyCap)
        internal {
            address[] memory tokenHolders;
            TokenProps memory newToken = TokenProps(
               tokenIDs.length + 1,
               _newURI,
               _amount,
               _supplyCap, 
               _isMintable,
               tokenHolders
               );
            tokenIDs.push(newToken);

           require(_mint(_msgSender(), newToken.tokenID, _amount, ""), "Minting failed");
            /*
           */
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
         uint256[] calldata _supplyCaps)
         external
         onlyOwners
         returns (bool) {
             // Check that all arrays are same length
            require(
                _newURIs.length == _isMintable.length &&
                _isMintable.length == _amounts.length &&
                _amounts.length == _supplyCaps.length, "Data fields must have same length");
            
            // Iterate through input arrays, create new token on each iteration
            for (uint i = 0; i <= _newURIs.length; i++) {
                string memory newURI = _newURIs[i];
                bool isMintable_ = _isMintable[i];
                uint256 amount = _amounts[i];
                uint256 supplyCap = _supplyCaps[i];

                _createToken(
                    newURI, 
                    isMintable_,
                    amount,
                    supplyCap
                );
            }            
            return true;
    }

    /**
     * @dev Mints more copies of a created token.
     *
     * If seller provided isMintable == false, then this function will revert
     */
    function mint(
         address _mintTo, 
         uint256 _tokenID, 
         uint256 _amount, 
         string memory, 
         bytes memory) 
        external 
        onlyOwners 
        isMintable(_tokenID) 
        returns (bool) {
         TokenProps memory tokenProperties = tokenIDs[_tokenID - 1];
         require(tokenProperties.totalSupply > 0, "Token does not exist");
         if (tokenProperties.supplyCap != 0){
            // Check that new amount does not exceed the supply cap
            require(tokenProperties.totalSupply + _amount <= tokenProperties.supplyCap, "Amount exceeds cap");
         }
         _mint(_mintTo, _tokenID, _amount, "");
         return true;
    }

    /**
     * @dev Performs an airdrop of _tokenID to all _recipients
     *
     * @param _tokenID Token being airdropped
     * @param _recipients Array of all airdrop recipients
     * @return Success bool
     */
/*
    function airdropTokens(uint256 _tokenID, uint256 _amount, address[] memory _recipients) external onlyOwners returns (bool) {
        require(balanceOf(_msgSender(), _tokenID) >= _recipients.length * _amount, "Not enough tokens for airdrop");
        for(uint i = 0; i < _recipients.length; i++){
            if(_recipients[i] == address(0)){
                continue;
            }
            else _safeTransferFrom(_msgSender(), _recipients[i], _tokenID, _amount, "");
        }
        return true;
    }
*/
    /**
     * @dev Overloaded version of airdropTokens() that can airdrop multiple tokenIDs to each _recipients[j]
     */
    function airdropTokens(uint256[] memory _tokenIDs, uint256[] memory _amounts, address[] memory _recipients) external onlyOwners returns (bool) {
        require(_amounts.length == _tokenIDs.length, "Amounts and tokenIDs must be same length");
        uint i; // TokenID and amount counter
        uint j; // Recipients counter
        // Iterate through each tokenID:
        for(i = 0; i < _tokenIDs.length; i++){
            require(balanceOf(_msgSender(), _tokenIDs[i]) >= _recipients.length, "Not enough tokens for airdrop");
            // Iterate through recipients, transfer tokenID if recipient != address(0)
            for(j = 0; j < _recipients.length; j++){
                if (_recipients[j] == address(0)) continue; // Skip address(0)
                else _safeTransferFrom(_msgSender(), _recipients[j], _tokenIDs[i], _amounts[i], "");
            }
        }
        return true;
    }    

    /**
     * @dev This overloaded version will send _tokenToDrop to every valid address in the tokenHolders
     * array found at tokenIDs[_tokenToCheck]. This is much simpler to call, but cannot be given an
     * arbitrary array of recipients for the airdrop.
     */
/*
    function airdropTokens(uint256 _tokenToDrop, uint256 _tokenToCheck, uint256 _amount) external onlyOwners returns (bool) {
        address[] memory tokenHolders = tokenIDs[_tokenToCheck - 1].tokenHolders;
        require(balanceOf(_msgSender(), _tokenToDrop) >= tokenHolders.length * _amount, "Insufficient tokens");

        for(uint i = 0; i < tokenHolders.length; i++){
            if (tokenHolders[i] == address(0)) continue;
            else _safeTransferFrom(_msgSender(), tokenHolders[i], _tokenToDrop, _amount, "");
        }
        return true;
    }        
*/
    /**
     * -----------------------------------
     *     ERC1155 STANDARD FUNCTIONS
     * -----------------------------------
     */

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IERC1155).interfaceId
            || interfaceId == type(IERC1155MetadataURI).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /**
     * @dev This implementation returns the URI stored for any _tokenID,
     * overwrites ERC1155's uri() function while maintaining compatibility
     * with OpenSea's standards.
     */
    function uri(uint256 _tokenID) public view virtual override returns (string memory) {
        return tokenIDs[_tokenID - 1].uri;
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
    function _setURI(string memory _newURI, uint256 _tokenID) internal virtual {
        tokenIDs[_tokenID - 1].uri = _newURI;
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
    function balanceOfBatch(
            address[] memory accounts,
            uint256[] memory ids
        )
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
     * @dev See {IERC1155-safeTransferFrom}.
     */
    function safeTransferFrom(
         address from,
         address to,
         uint256 id,
         uint256 amount,
         bytes memory data
        )
        public
        virtual
        override
        {
         require(
            isOwner[from],
            "PazariToken: Caller is not an owner"
         );
         _safeTransferFrom(from, to, id, amount, data);
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
        )
        public
        virtual
        override
        {
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
        )
        internal
        virtual
        {
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
        )
        internal
        virtual
        {
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
     * @dev Burns copies of a token from a token owner's address.
     *
     * This can be called by anyone, and if they burn all of their tokens then
     * their address in tokenOwners[tokenID] will be set to address(0). However,
     * their tokenOwnerIndex[] value will not be deleted, as it will be used to
     * put them back on the list of tokenOwners if they receive another token.
     */
    function burn(uint256 _tokenID, uint256 _amount) external returns (bool) {
        _burn(msg.sender, _tokenID, _amount);
        if(balanceOf(msg.sender, _tokenID) == 0){
            tokenIDs[_tokenID - 1].tokenHolders[tokenOwnerIndex[msg.sender][_tokenID]] = address(0);
        }
        return true;
    }

    /**
     * @dev Burns a batch of tokens from the caller's address.
     *
     * This can be called by anyone, and if they burn all of their tokens then
     * their address in tokenOwners[tokenID] will be set to address(0). However,
     * their tokenOwnerIndex[] value will not be deleted, as it will be used to
     * put them back on the list of tokenOwners if they receive another token.
     */
    function burnBatch(uint256[] calldata _tokenIDs, uint256[] calldata _amounts) external returns (bool) {
       _burnBatch(msg.sender, _tokenIDs, _amounts);
       for(uint i = 0; i < _tokenIDs.length; i++){
            if(balanceOf(msg.sender, _tokenIDs[i]) == 0){
                tokenIDs[_tokenIDs[i] - 1].tokenHolders[tokenOwnerIndex[msg.sender][_tokenIDs[i]]] = address(0);
            }
       }
       return true;
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
    function _mint(address account, uint256 id, uint256 amount, bytes memory data) internal virtual returns (bool) {
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
    function _mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) internal virtual returns (bool) {
        require(to != address(0), "ERC1155: mint to the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

        for (uint i = 0; i < ids.length; i++) {
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
    function _burn(address account, uint256 id, uint256 amount) internal virtual returns (bool) {
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
    function _burnBatch(address account, uint256[] memory ids, uint256[] memory amounts) internal virtual returns (bool) {
        require(account != address(0), "ERC1155: burn from the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, account, address(0), ids, amounts, "");

        for (uint i = 0; i < ids.length; i++) {
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
        )
        internal
        virtual
    { 
        bool[] memory tempBools = ownsToken(ids, to);
        // If recipient does not own a token, then add their address to tokenHolders
        for(uint i = 0; i < ids.length; i++){
            if(tempBools[i]){
                tokenIDs[ids[i] - 1].tokenHolders.push(to);
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
        )
        private
    {
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
        )
        private
    {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (bytes4 response) {
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








