/**
 * @dev All MVP default values are specified in comments. These are the values that
 * the front-end should give to the contract for the Pazari MVP. After the MVP we
 * can begin building out the rest of the functions.
 */

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IMarketplace {
  // EVENTS
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
    address owner;
    uint256 price;
    address paymentContract;
    bool isPush;
    bytes32 routeID;
    bool routeMutable;
    bool forSale;
    uint256 itemLimit;
  }

  // FUNCTIONS

  /**
   * @notice Creates a MarketItem struct and assigns it an itemID
   *
   * @param _tokenContract Token contract address of the item being sold
   * @param _ownerAddress Owner's address that can access modifyMarketItem() (MVP: msg.sender)
   * @param _tokenID The token contract ID of the item being sold
   * @param _amount The amount of items available for purchase (MVP: 0)
   * @param _price The price--in payment tokens--of the item being sold
   * @param _paymentContract Contract address of token accepted for payment (MVP: stablecoin)
   * @param _isPush Tells PaymentRouter to use push or pull function for this item (MVP: true)
   * @param _forSale Sets whether item is immediately up for sale (MVP: true)
   * @param _routeID The routeID of the payment route assigned to this item
   * @param _itemLimit How many items a buyer can own, 0 == no limit (MVP: 1)
   * @param _routeMutable Assigns mutability to the routeID, keep false for most items (MVP: false)
   * @return itemID ItemID of the market item
   *
   * @dev Emits MarketItemCreated event
   *
   * @dev Front-end must call IERC1155.setApprovalForAll(marketAddress, true) for any ERC1155 token
   * that is NOT a Pazari1155 contract. Pazari1155 will have auto-approval for Marketplace.
   */
  function createMarketItem(
    address _tokenContract,
    address _ownerAddress,
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
   * @notice Accesses the marketItems[] array
   * @return MarketItem MarketItem struct stored at _index
   *
   * @dev _index = itemID - 1
   */
  function marketItems(uint256 _index) external view returns (MarketItem memory);

  /**
   * @notice Purchases an _amount of market item itemID
   *
   * @param _itemID Market ID of item being bought
   * @param _amount Amount of item itemID being purchased (MVP: 1)
   * @return bool Success boolean
   *
   * @dev Emits ItemSoldOut when last item is bought and MarketItemSold for every purchase
   *
   * @dev Providing _amount == 0 will purchase the item's full itemLimit.
   */
  function buyMarketItem(uint256 _itemID, uint256 _amount) external returns (bool);

  /**
   * @notice Transfers more stock to a MarketItem, requires minting more tokens first and setting
   * approval for Marketplace.
   *
   * @dev NOT USED FOR MVP
   *
   * @param _itemID MarketItem ID
   * @param _amount Amount of tokens being restocked
   *
   * @dev Emits ItemRestocked event
   */
  function restockItem(uint256 _itemID, uint256 _amount) external;

  /**
   * @notice Removes _amount of item tokens for _itemID and transfers back to seller's wallet
   *
   * @dev NOT USED FOR MVP
   *
   * @param _itemID MarketItem's ID
   * @param _amount Amount of tokens being pulled from Marketplace, 0 == pull all tokens
   *
   * @dev Emits StockPulled event
   */
  function pullStock(uint256 _itemID, uint256 _amount) external;

  /**
   * @notice Function that allows item creator to change price, accepted payment
   * token, whether token uses push or pull routes, and payment route.
   *
   * @dev MVP SHOULD ONLY CHANGE PRICE
   *
   * @param _itemID Market item ID
   * @param _price Market price--in stablecoins
   * @param _paymentContract Contract address of token accepted for payment (MVP: stablecoin address)
   * @param _isPush Tells PaymentRouter to use push or pull function (MVP: true)
   * @param _routeID Payment route ID, only mutable if routeMutable == true (MVP: 0)
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
   * @notice Toggles whether an item is for sale or not
   *
   * @dev Use this function to activate/deactivate items for sale on market. Only items that are
   * forSale will be returned by getInStockItems().
   *
   * @param _itemID Marketplace ID of item for sale
   *
   * @dev Emits ForSaleToggled event
   */
  function toggleForSale(uint256 _itemID) external;

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
   * @notice Checks if an address owns any itemIDs
   *
   * @param _owner The address being checked
   * @param _itemIDs Array of item IDs being checked
   *
   * @dev This function can be used to check for tokens across multiple contracts, and is better than the
   * ownsTokens() function in the PazariTokenMVP contract. This is the only function we will need to call.
   */
  function ownsTokens(address _owner, uint256[] memory _itemIDs) external view returns (bool[] memory);
}
