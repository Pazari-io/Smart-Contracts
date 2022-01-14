/**
 * @dev All MVP default values are specified in comments. These are the values that
 * the front-end should give to the contract for the Pazari MVP. After the MVP we
 * can begin building out the rest of the functions.
 */

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IMarketplace {
  //***EVENTS***\\

  // Fires when a MarketItem is sold;
  event MarketItemSold(uint256 indexed itemID, uint256 amount, address owner);

  // Fires when a creator restocks MarketItems that are sold out
  event ItemRestocked(uint256 indexed itemID, uint256 amount);

  // Fires when a MarketItem's last token is bought
  event ItemSoldOut(uint256 indexed itemID);

  // Fires when forSale is toggled on or off for an itemID
  // If forSale == true, then forSale was toggled on
  // If forSale == false, then forSale was toggled off
  event ForSaleToggled(uint256 itemID, bool forSale);

  // Fires when a creator pulls a MarketItem's stock from the Marketplace
  event StockPulled(uint256 itemID, uint256 amount);

  // Fires when market item details are modified
  event MarketItemChanged(
    uint256 itemID,
    uint256 price,
    address paymentContract,
    bool isPush,
    bytes32 routeID,
    uint256 itemLimit
  );

  // Struct for market items being sold;
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
   * @notice Overloaded function that takes less parameters
   * @dev Assumes the following values:
   * - isPush = true
   * - forSale = true
   * - itemLimit = 1
   * - routeMutable = false
   * @return itemID The itemID of the new MarketItem
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
   * @dev Emits ItemSoldOut when last item is bought and MarketItemSold for every purchase
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
   * @return Sucess boolean
   *
   * @dev Emits MarketItemChanged event
   */
  function modifyMarketItem(
    uint256 _itemID,
    uint256 _price,
    address _paymentContract,
    bool _isPush,
    bytes32 _routeID,
    uint256 _itemLimit
  ) external returns (bool);

  /**
   * @dev Toggles whether an item is for sale or not
   *
   * @dev Use this function to activate/deactivate items for sale on market. Only items that are
   * forSale will be returned by getInStockItems().
   *
   * @param _itemID Marketplace ID of item for sale
   * @return forSale True = item was reactivated, false = item was deactivated
   */
  function toggleForSale(uint256 _itemID) external returns (bool forSale);

  /**
   * @notice This is in case someone mistakenly sends their ERC1155 NFT to this contract address
   * @dev If tokenID is a MarketItem, then it will only send back the excess tokens not accounted
   * for by MarketItem.amount.
   *
   * @param _nftContract Contract address of NFT to recover
   * @param _tokenID Token ID of the NFT to recover
   * @param _amount Amount of tokens to recover
   */
  function recoverNFT(
    address _nftContract,
    uint256 _tokenID,
    uint256 _amount
  ) external returns (bool);

  //***FUNCTIONS: GETTERS***\\

  /**
   * @notice Directly accesses the marketItems[] array
   * @return MarketItem MarketItem struct stored at _index
   *
   * @dev _index = itemID - 1
   */
  function marketItems(uint256 _index) external view returns (MarketItem memory);

  /**
   * @notice Returns an array of all items for sale on marketplace
   */
  function getItemsForSale() external view returns (MarketItem[] memory);

  /**
   * @notice Getter function for all itemIDs with forSale.
   */
  function getItemIDsForSale() external view returns (uint256[] memory itemIDs);

  /**
   * @notice Returns an array of MarketItem structs given an array of _itemIDs.
   */
  function getMarketItems(uint256[] memory _itemIDs) external view returns (MarketItem[] memory marketItems_);

  /**
   * @notice Returns an array of MarketItems created the seller's address
   * @dev No restrictions for calling this
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
 * @dev Not needed for MVP, but they're here if needed
 */
interface IAccessControlMP {
  // Fires when admins are added or removed
  event AdminAdded(address newAdmin, address adminAuthorized, string memo, uint256 timestamp);
  event AdminRemoved(address oldAdmin, address adminAuthorized, string memo, uint256 timestamp);

  // Fires when item admins are added or removed
  event ItemAdminAdded(
    uint256 itemID,
    address newAdmin,
    address adminAuthorized,
    string memo,
    uint256 timestamp
  );
  event ItemAdminRemoved(
    uint256 itemID,
    address oldAdmin,
    address adminAuthorized,
    string memo,
    uint256 timestamp
  );

  // Fires when an address is blacklisted/whitelisted from the Pazari Marketplace
  event AddressBlacklisted(address blacklistedAddress, address adminAddress, string memo, uint256 timestamp);
  event AddressWhitelisted(address whitelistedAddress, address adminAddress, string memo, uint256 timestamp);

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

  // Adds an address to isAdmin mapping
  function addAdmin(address _newAddress, string memory _memo) external returns (bool);

  // Removes an address from isAdmin mapping
  function removeAdmin(address _oldAddress, string memory _memo) external returns (bool);

  // Adds an address to isItemAdmin mapping
  function addItemAdmin(
    uint256 _itemID,
    address _newAddress,
    string memory _memo
  ) external returns (bool);

  // Removes an address from isItemAdmin mapping
  function removeItemAdmin(
    uint256 _itemID,
    address _oldAddress,
    string memory _memo
  ) external returns (bool);

  /**
   * @notice Toggles isBlacklisted for an address. Can only be called by Pazari
   * Marketplace admins.
   */
  function toggleBlacklist(address _listedAddress, string memory _memo) external returns (bool);
}
