// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPazariMVP {
  // Fires when a new token is listed for sale
  event NewTokenListed(
    uint256 indexed itemID,
    address indexed tokenContract,
    uint256 price,
    uint256 tokenID,
    uint256 amount,
    string uri,
    address indexed sender
  );

  // Fires when a new user joins and lists an item
  event NewUserCreated(
    address indexed userAddress, 
    bytes32 routeID, 
    address tokenContractAddress, 
    uint256 timestamp
  );

  /**
   * @notice Fires when a new PazariTokenMVP contract is cloned
   *
   * @param contractID Unique identifier for the contract created
   * @param contractType Number representing type of contract created (see below)
   * @param creatorAddress Address of contract's creator
   * @param factoryAddress Address of factory that created the contract
   * @param cloneAddress Address of cloned token contract
   * @param timestamp Block timestamp when contract was created
   *
   * @dev All ContractCloned events from PazariMVP will have contractType = 0,
   * so it is not indexed. Instead, we can filter by contractID, creator's
   * address, and the factory's address.
   */
  event ContractCloned(
    uint256 indexed contractID,
    uint16 contractType,
    address indexed creatorAddress,
    address factoryAddress,
    address indexed cloneAddress,
    uint256 timestamp
  );

  // Fires when admin recovers lost NFT(s)
  event NFTRecovered(
    address indexed tokenContract, 
    uint256 indexed tokenID, 
    address recipient, 
    address indexed admin, 
    string memo, 
    uint256 timestamp
  );

  /**
   * @notice General information about a user's profile
   * @param userAddress User's address, determined by _msgSender()
   * @param tokenContract Address of PazariTokenMVP contract associated with user profile
   * @param routeID Bytes32 ID of user's PaymentRoute
   * @param itemIDs Array of all itemIDs created by this user
   */
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
   * @notice Creates a new token and lists it on the Pazari Marketplace.
   * @dev If user does not have a profile yet, then one is created and
   * a new token contract is cloned and deployed.
   *
   * @param _URI URL to token's public metadata
   * @param _amount Amount of tokens to mint and list
   * @param _price Listing price per token
   * @return tokenID The tokenID and itemID of the new token listed
   *
   * @dev Emits NewTokenListed event
   */
  function newTokenListing(
    string memory _URI,
    uint256 _amount,
    uint256 _price
  ) external returns (uint256 tokenID, uint256 itemID);

  /**
   * @notice This is in case someone mistakenly sends their ERC1155
   * NFT to this contract address
   * @dev Only PazariMVP admins can call this function
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

  // Accesses itemIDs array of all itemIDs created through PazariMVP
  function itemIDs(uint256 _index) external view returns (uint256 itemID);

  // Accesses deployedContracts array of all cloned token contracts created by PazariMVP
  function deployedContracts(uint256 _index) external view returns (address contractAddress);
}


interface IAccessControlPMVP {
  // Fires when Pazari admins are added/removed
  event AdminAdded(
    address indexed newAdmin, 
    address indexed adminAuthorized, 
    string memo, 
    uint256 timestamp
  );
  event AdminRemoved(
    address indexed oldAdmin,
    address indexed adminAuthorized,
    string memo,
    uint256 timestamp
  );

  // Accesses isAdmin mapping, only Pazari admins will have isAdmin for PazariMVP
  function isAdmin(address _userAddress) external view returns (bool);

  /**
   * @notice Returns tx.origin for any Pazari-owned admin contracts, returns msg.sender
   * for everything else. See IPaymentRouter for more details.
   */
  function _msgSender() external view returns (address);

  /**
   * @notice Adds or removes an address as an admin
   * @dev Only admins or admin contracts operated by admins can call these functions
   *
   * @param _newAddress/_oldAddress Address being added/removed to/from isAdmin
   * @param _memo Optional admin's note emitted by event
   * @return bool Success bool
   *
   * @dev Emits AdminAdded event when address is given isAdmin
   * @dev Emits AdminRemoved event when isAdmin is taken away from an address
   */
  function addAdmin(address _newAddress, string calldata _memo) external returns (bool);
  function removeAdmin(address _oldAddress, string calldata _memo) external returns (bool);
}
