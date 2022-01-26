// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMarketplace {
  //***EVENTS***\\

  // Fires when a new MarketItem is created;
  event MarketItemCreated(
    uint256 indexed itemID,
    address indexed nftContract,
    uint256 tokenID,
    address indexed admin,
    uint256 price,
    uint256 amount,
    address paymentToken
  );

  // Fires when a MarketItem is sold;
  event MarketItemSold(uint256 indexed itemID, uint256 amount, address indexed buyer);

  // Fires when a MarketItem's last token is bought
  event ItemSoldOut(uint256 indexed itemID);

  // Fires when a creator restocks MarketItems that are sold out
  event ItemRestocked(uint256 indexed itemID, uint256 amount);

  // Fires when a creator pulls a MarketItem's stock from the Marketplace
  event ItemPulled(uint256 indexed itemID, uint256 amount);

  // Fires when forSale is toggled on or off for an itemID
  event ForSaleToggled(uint256 indexed itemID, bool forSale);

  // Fires when a MarketItem has been deleted
  event MarketItemDeleted(uint256 indexed itemID, address indexed itemAdmin, uint256 timestamp);

  // Fires when market item details are modified
  event MarketItemChanged(
    uint256 indexed itemID,
    uint256 indexed price,
    address paymentContract,
    bool isPush,
    bytes32 indexed routeID,
    uint256 itemLimit
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

  // Struct for market items being sold;
  struct MarketItem {
    uint256 itemID;
    uint256 tokenID;
    uint256 price;
    uint256 amount;
    uint256 itemLimit;
    bytes32 routeID;
    address tokenContract;
    address paymentContract;
    bool isPush;
    bool routeMutable;
    bool forSale;
  }

  //***FUNCTIONS: SETTERS***\\

  /**
   * @notice Creates a MarketItem struct and assigns it an itemID
   * @notice This version is for custom MarketItems
   *
   * @param _tokenContract Token contract address of the item being sold
   * @param _tokenID The token contract ID of the item being sold
   * @param _amount The amount of items available for purchase (MVP: 0)
   * @param _price The price--in payment tokens--of the item being sold
   * @param _paymentContract Contract address of token accepted for payment (MVP: stablecoin)
   * @param _isPush Tells PaymentRouter to use push or pull function for this item (MVP: true)
   * @param _forSale Sets whether item is immediately up for sale (MVP: true)
   * @param _routeID The routeID of the payment route assigned to this item
   * @param _itemLimit How many items a buyer can own, 0 == no limit (MVP: 1)
   * @param _routeMutable Assigns mutability to the routeID, keep false for most items (MVP: false)
   * @return itemID The itemID of the new MarketItem
   *
   * Emits MarketItemCreated event
   */
  function createMarketItem(
    address _tokenContract,
    uint256 _tokenID,
    uint256 _amount,
    uint256 _price,
    address _paymentContract,
    bool _isPush,
    bool _forSale,
    bytes32 _routeID,
    uint256 _itemLimit,
    bool _routeMutable
  ) external returns (uint256 itemID);

  /**
   * @notice Lighter overload of createMarketItem
   *
   * @param _tokenContract Token contract address of the item being sold
   * @param _tokenID The token contract ID of the item being sold
   * @param _amount The amount of items available for purchase (MVP: 0)
   * @param _price The price--in payment tokens--of the item being sold
   * @param _paymentContract Contract address of token accepted for payment (MVP: stablecoin)
   * @param _routeID The routeID of the payment route assigned to this item
   * @return itemID ItemID of the market item
   */
  function createMarketItem(
    address _tokenContract,
    uint256 _tokenID,
    uint256 _amount,
    uint256 _price,
    address _paymentContract,
    bytes32 _routeID
  ) external returns (uint256 itemID);

  /**
   * @notice Purchases an _amount of market item itemID
   *
   * @param _itemID Market ID of item being bought
   * @param _amount Amount of item itemID being purchased (MVP: 1)
   * @return bool Success boolean
   *
   * @dev Emits ItemSoldOut event when last item is bought
   * @dev Emits MarketItemSold event for every purchase
   *
   * @dev Providing _amount == 0 will purchase the item's full itemLimit, which
   * for most items will be 1
   */
  function buyMarketItem(uint256 _itemID, uint256 _amount) external returns (bool);

  /**
   * @notice Transfers more stock to a MarketItem, requires minting more tokens first and setting
   * approval for Marketplace.
   *
   * @param _itemID MarketItem ID
   * @param _amount Amount of tokens being restocked
   * @return bool Success bool
   *
   * @dev Emits ItemRestocked event
   */
  function restockItem(uint256 _itemID, uint256 _amount) external returns (bool);

  /**
   * @notice Removes _amount of item tokens for _itemID and transfers back to seller's wallet
   *
   * @param _itemID MarketItem's ID
   * @param _amount Amount of tokens being pulled from Marketplace, 0 == pull all tokens
   * @return bool Success bool
   *
   * @dev Emits StockPulled event
   */
  function pullStock(uint256 _itemID, uint256 _amount) external returns (bool);

  /**
   * @notice Function that allows item creator to change price, accepted payment
   * token, whether token uses push or pull routes, and payment route.
   *
   * @param _itemID Market item ID
   * @param _price Market price--in stablecoins
   * @param _paymentContract Contract address of token accepted for payment (MVP: stablecoin address)
   * @param _isPush Tells PaymentRouter to use push or pull function (MVP: true)
   * @param _routeID Payment route ID, only useful if routeMutable == true (MVP: 0)
   * @param _itemLimit Buyer's purchase limit for item (MVP: 1)
   * @param _forSale Determines if item can be purchased (MVP: true)
   * @return Success boolean
   *
   * @dev Emits MarketItemChanged event
   * @dev Emits ForSaleToggled if _forSale is different
   */
  function modifyMarketItem(
    uint256 _itemID,
    uint256 _price,
    address _paymentContract,
    bool _isPush,
    bytes32 _routeID,
    uint256 _itemLimit,
    bool _forSale
  ) external returns (bool);

  /**
   * @notice Deletes a MarketItem, setting all its properties to default values
   * @dev Does not remove itemID or the entry in marketItems, just sets properties to default
   * and removes tokenMap mappings. This frees up the tokenID to be used in a new MarketItem.
   * @dev Only the itemCreator or a Pazari admin can call this function
   *
   * @dev Emits MarketItemDeleted event
   */
  function deleteMarketItem(uint256 _itemID) external returns (bool);

  /**
   * @notice This is in case someone mistakenly sends their ERC1155 NFT to this contract address
   * @dev Requires both tx.origin and msg.sender be admins
   *
   * @param _nftContract Contract address of NFT being recovered
   * @param _tokenID Token ID of NFT
   * @param _amount Amount of NFTs to recover
   * @param _recipient Where the NFTs are going
   * @param _memo Any notes the admin wants to include in the event
   * @return bool Success bool
   *
   * @dev Emits NFTRecovered event
   */
  function recoverNFT(
    address _nftContract,
    uint256 _tokenID,
    uint256 _amount,
    address _recipient,
    string calldata _memo
  ) external returns (bool);

  //***FUNCTIONS: GETTERS***\\

  /**
   * @notice Directly accesses the marketItems[] array
   *
   * @param _index Array index position, _index = itemID - 1
   * @return MarketItem MarketItem struct stored at _index
   */
  function marketItems(uint256 _index) external view returns (MarketItem memory);

  /**
   * @notice Getter function for all itemIDs with forSale.
   */
  function getItemIDsForSale() external view returns (uint256[] memory itemIDs);

  /**
   * @notice Returns an array of MarketItem structs given an array of _itemIDs.
   */
  function getMarketItems(uint256[] memory _itemIDs) external view returns (MarketItem[] memory marketItems_);

  /**
   * @notice Returns an array of MarketItems created by the seller's address
   * @dev Used for displaying seller's items for mini-shops on seller profiles
   * @dev There is no way to remove items from this array, and deleted itemIDs will still show,
   * but will have nonexistent item details.
   */
  function getSellersMarketItems(address _sellerAddress) external view returns (uint256[] memory);

  /**
   * @notice Checks if an address owns any itemIDs
   *
   * @param _owner The address being checked
   * @param _itemIDs Array of item IDs being checked
   *
   * @dev This function can be used to check for tokens across multiple contracts, and is better than the
   * ownsTokens() function in the PazariTokenMVP contract. This is the only function we will need to call.
   */
  function ownsTokens(address _owner, uint256[] memory _itemIDs)
    external
    view
    returns (bool[] memory hasToken);
}

/**
 * @notice All access control functions and events used by Marketplace
 * @dev Contains functions and events for Pazari admins and seller item admins, as
 * well as managing the blacklist. Contains modifier for reentrancy guards.
 */
interface IAccessControlMP {
  // Fires when Pazari admins are added/removed
  event AdminAdded(address indexed newAdmin, address indexed adminAuthorized, string memo, uint256 timestamp);
  event AdminRemoved(
    address indexed oldAdmin,
    address indexed adminAuthorized,
    string memo,
    uint256 timestamp
  );

  // Fires when item admins are added or removed
  event ItemAdminAdded(
    uint256 indexed itemID,
    address indexed newAdmin,
    address indexed adminAuthorized,
    string memo,
    uint256 timestamp
  );
  event ItemAdminRemoved(
    uint256 indexed itemID,
    address indexed oldAdmin,
    address indexed adminAuthorized,
    string memo,
    uint256 timestamp
  );

  // Fires when an address is blacklisted/whitelisted from the Pazari Marketplace
  event AddressBlacklisted(
    address indexed blacklistedAddress,
    address indexed adminAddress,
    string memo,
    uint256 timestamp
  );
  event AddressWhitelisted(
    address indexed whitelistedAddress,
    address indexed adminAddress,
    string memo,
    uint256 timestamp
  );

  /**
   * @notice Returns tx.origin for any Pazari-owned admin contracts, returns msg.sender
   * for everything else. See IPaymentRouter for more details.
   */
  function _msgSender() external view returns (address);

  // Accesses isAdmin mapping
  function isAdmin(address _addressToCheck) external view returns (bool);

  // Accesses isItemAdmin mapping
  function isItemAdmin(bytes32 _itemID, address _addressToCheck) external view returns (bool);

  // Accesses isBlacklisted mapping
  function isBlacklisted(address _addressToCheck) external view returns (bool);

  // Accesses itemCreator mapping
  function itemCreator(uint256 _itemID) external view returns (address itemCreator);

  /**
   * @notice Adds an address to isAdmin mapping
   * @dev Only admins and admin contracts operated by admins may call
   *
   * @param _newAddress Address being added
   * @param _memo Optional message to include in event emission
   * @return bool Success bool
   *
   * @dev Emits AdminAdded event
   */
  function addAdmin(address _newAddress, string calldata _memo) external returns (bool);

  /**
   * @notice Removes an address from isAdmin mapping
   * @dev Only admins and admin contracts operated by admins may call
   *
   * @param _oldAddress Address being removed
   * @param _memo Optional message to include in event emission
   * @return bool Success bool
   *
   * @dev Emits AdminRemoved event
   */
  function removeAdmin(address _oldAddress, string calldata _memo) external returns (bool);

  /**
   * @notice Adds an address to isItemAdmin mapping
   * @dev Only admins and itemAdmins may call
   *
   * @param _newAddress Address being added
   * @param _itemID Marketplace itemID of MarketItem
   * @param _memo Optional message to include in event emission
   * @return bool Success bool
   *
   * @dev Emits ItemAdminAdded event
   */
  function addItemAdmin(
    uint256 _itemID,
    address _newAddress,
    string calldata _memo
  ) external returns (bool);

  /**
   * @notice Removes an address from isItemAdmin mapping
   * @dev Only admins and itemAdmins may call
   *
   * @param _oldAddress Address being removed
   * @param _itemID Marketplace itemID of MarketItem
   * @param _memo Optional message to include in event emission
   * @return bool Success bool
   *
   * @dev Emits ItemAdminRemoved event
   */
  function removeItemAdmin(
    uint256 _itemID,
    address _oldAddress,
    string calldata _memo
  ) external returns (bool);

  /**
   * @notice Toggles isBlacklisted for an address
   * @dev Only Pazari admins and admin contracts operated by admins can call
   *
   * @param _userAddress Address being black/whitelisted
   * @param _memo Optional message to emit in event
   * @return bool Success bool
   *
   * @dev Emits AddressBlacklisted event if address has isBlacklisted
   * @dev Emits AddressWhitelisted event if address has !isBlacklisted
   */
  function toggleBlacklist(address _userAddress, string calldata _memo) external returns (bool);
}
