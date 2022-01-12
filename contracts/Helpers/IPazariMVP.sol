// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPazariMVP {

  // Fires when a new token is listed for sale
  event NewTokenListed(
    address indexed itemOwner,
    uint256 itemID,
    uint256 indexed price,
    address indexed tokenContract,
    uint256 tokenID,
    uint256 amount
  );

  // Fires when a new user joins and lists an item
  event NewUserCreated(
    address userAddress, 
    bytes32 routeID, 
    address tokenContractAddress, 
    uint256 itemID, 
    uint256 timestamp
  );

  // Fires after a token contract is cloned
  event ContractCloned(
    uint contractID, 
    uint16 indexed contractType,
    address indexed creatorAddress,
    address indexed factoryAddress, 
    address cloneAddress, 
    uint256 timestamp
  );

  // Created for everyone who runs newUser()
  struct UserProfile {
    address userAddress;
    address tokenContract;
    bytes32 routeID;
    uint256[] itemIDs;
  }

  // Struct for market items being sold, returned by getMarketItem()
  struct MarketItem {
    uint256 itemID;
    address tokenContract;
    uint256 tokenID;
    uint256 amount;
    uint256 price;
    address paymentContract;
    bool isPush;
    bytes32 routeID;
    bool routeMutable;
    bool forSale;
    uint256 itemLimit;
  }  

  /**
   * @notice Auto-generates a new payment route, clones a token contract, mints a token, and lists
   * it on the Pazari marketplace in one turn. This function only needs three inputs.
   *
   * @param _URI URL of the JSON public metadata file, usually an IPFS URI
   * @param _amount Amount of tokens to be minted and listed
   * @param _price Price in USD for each token.
   * @return UserProfile The newly created UserProfile struct
   */
  function createUserProfile(
    string memory _URI,
    uint256 _amount,
    uint256 _price
  ) external returns (UserProfile memory);

  /**
   * @notice Creates a new token and lists it on the Pazari Marketplace
   * @return tokenID The tokenID and itemID of the new token listed
   *
   * @dev Assumes the seller is using the same PaymentRoute and token contract
   * created in newUser().
   *
   * @dev Emits NewTokenListed event
   */
  function newTokenListing(
    string memory _URI,
    uint256 _amount,
    uint256 _price
  ) external returns (uint256 tokenID, uint256 itemID);

  /**
   * @notice This is in case someone mistakenly sends their ERC1155 NFT to this contract address
   * @dev Only PazariMVP admins can call this function, and is the only function they can call.
   */
  function recoverNFT(
    address _nftContract,
    uint256 _tokenID,
    uint256 _amount,
    address _to
  ) external returns (bool);

  /**
   * @notice Returns a user's UserProfile struct
   */
  function getUserProfile(address _userAddress) external view returns (UserProfile memory);

  /**
   * @notice Returns the MarketItem struct for a single _itemID
   * @dev If we need to return multiple MarketItems, then use iMarketplace.getMarketItems()
   * @dev This function is much easier to use as it does not need arrays, but it only returns
   * one MarketItem struct.
   */
  function getMarketItem(uint256 _itemID) external view returns (MarketItem memory);

}

interface AccessControlPMVP {

  function isAdmin(address _userAddress) external view returns (bool);

  function _msgSender() external view returns (address);

  function addAdmin(address _newAddress, string memory _memo) external returns (bool);

  function removeAdmin(address _oldAddress, string memory _memo) external returns (bool);
}
