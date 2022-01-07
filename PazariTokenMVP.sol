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
import "./Pazari1155.sol";

contract PazariTokenMVP is Pazari1155 {
    using Address for address;

    // Fires when a new token is created through createNewToken()
    event TokenCreated(string URI, uint256 indexed tokenID, uint256 amount);

    // Fires when more tokens are minted from a pre-existing tokenID
    event TokensMinted(address indexed mintTo, uint256 indexed tokenID, uint256 amount);

    // Fires when a contract owner adds a new owner to the contract
    event OwnerAdded(address indexed newOwner, address indexed tokenContract);

    constructor(address[] memory _contractOwners) Pazari1155(_contractOwners){}

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
     * @notice Adds new owner addresses, only owners can call
     *
     * @dev Emits OwnerAdded event for each address added
     *
     * @dev All owners can call transferFrom() without operator approval, and they can
     * add new owners to the contract. This should ideally *never* be used for wallet
     * addresses, and should be limited to Pazari smart contracts. The only exception
     * is if a seller wants to share a token contract with a co-creator that they trust.
     * 
     * @dev This function exposes an attack vector if the wrong address is provided.
     */
    function addOwners(address[] memory _newOwners) external onlyOwners {
        for (uint i = 0; i < _newOwners.length; i++){
            address newOwner = _newOwners[i];
            _operatorApprovals[msg.sender][newOwner] = true;
            isOwner[newOwner] = true;
            emit OwnerAdded(newOwner, address(this));
        }
    }

    /**
     * @dev Returns an array of all holders of a _tokenID
     */
    function tokenHolders(uint256 _tokenID) external view returns (address[] memory) {
        return tokenIDs[_tokenID - 1].tokenHolders;
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
         bool _isMintable)
        external
        onlyOwners()
        returns (uint256) {
            uint256 tokenID;
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

            tokenID = _createToken(
                _newURI, 
                _isMintable,
                _amount,
                _supplyCap
            );           
            return tokenID; 
    }


    function _createToken(
        string memory _newURI, 
        bool _isMintable,
        uint256 _amount,
        uint256 _supplyCap)
        internal returns (uint256 tokenID) {
            address[] memory emptyTokenHoldersArray;
            TokenProps memory newToken = TokenProps(
               tokenIDs.length + 1,
               _newURI,
               _amount,
               _supplyCap, 
               _isMintable,
               emptyTokenHoldersArray
               );
            tokenIDs.push(newToken);
            tokenID = newToken.tokenID;

            require(_mint(_msgSender(), newToken.tokenID, _amount, ""), "Minting failed");

            emit TokenCreated(_newURI, newToken.tokenID, _amount);
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
         emit TokensMinted(_mintTo, _tokenID, _amount);
         return true;
    }

    /**
     * @dev Performs a multi-token airdrop of each _amounts[i] for each _tokenIDs[i] to each _recipients[j]
     *
     * @param _tokenIDs Tokens being airdropped
     * @param _amounts Amount of each token being sent to each recipient
     * @param _recipients All airdrop recipients
     * @return Success bool
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
     * @dev Overridden ERC1155 function, requires that the caller of the function
     * is an owner of the contract.
     */
    function safeTransferFrom(
         address from,
         address to,
         uint256 id,
         uint256 amount,
         bytes memory data
        )
        external
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
     * @dev This implementation returns the URI stored for any _tokenID,
     * overwrites ERC1155's uri() function while maintaining compatibility
     * with OpenSea's standards.
     */
    function uri(uint256 _tokenID) public view virtual override returns (string memory) {
        return tokenIDs[_tokenID - 1].uri;
    }


    

}








