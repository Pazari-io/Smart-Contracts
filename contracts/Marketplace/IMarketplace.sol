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
   * @dev Creates a MarketItem struct and assigns it an itemID
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
   * @param _routeMutable Assigns mutability to the routeID, keep false for most items (MVP: true)
   * @return itemID ItemID of the market item
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
   * @dev Accesses the marketItems[] array
   * @return MarketItem MarketItem struct stored at _index
   *
   * note _index = itemID - 1
   */
  function marketItems(uint256 _index) external returns (MarketItem memory);

  /**
   * @dev Purchases an _amount of market item itemID
   *
   * @param _itemID Market ID of item being bought
   * @param _amount Amount of item itemID being purchased (MVP: 1)
   * @return bool Success boolean
   *
   * note Providing _amount == 0 will purchase the item's full itemLimit minus
   * the buyer's existing balance. This way, if a buyer wants to max out the
   * amount of itemID they are allowed to own, then the front-end can just
   * pass 0 for _amount and the contract will do the rest.
   */
  function buyMarketItem(uint256 _itemID, uint256 _amount) external returns (bool);

  /**
   * @dev Transfers more stock to a MarketItem, requires minting more tokens first and setting
   * approval for Marketplace.
   *
   * NOT USED FOR MVP
   *
   * @param _itemID MarketItem ID
   * @param _amount Amount of tokens being restocked
   */
  function restockItem(uint256 _itemID, uint256 _amount) external;

  /**
   * @dev Removes _amount of item tokens for _itemID and transfers back to seller's wallet
   *
   * NOT USED FOR MVP
   *
   * @param _itemID MarketItem's ID
   * @param _amount Amount of tokens being pulled from Marketplace, 0 == pull all tokens
   */
  function pullStock(uint256 _itemID, uint256 _amount) external;

  /**
   * @dev Function that allows item creator to change price, accepted payment
   * token, whether token uses push or pull routes, and payment route.
   *
   * MVP SHOULD ONLY CHANGE PRICE
   *
   * @param _itemID Market item ID
   * @param _price Market price--in stablecoins
   * @param _paymentContract Contract address of token accepted for payment (MVP: stablecoin address)
   * @param _isPush Tells PaymentRouter to use push or pull function (MVP: true)
   * @param _routeID Payment route ID, only mutable if routeMutable == true (MVP: 0)
   * @param _itemLimit Buyer's purchase limit for item (MVP: 1)
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
   * Use this function to activate/deactivate items for sale on market. Only items that are
   * forSale will be returned by getItemsForSale() and getItemIDsForSale().
   *
   * @param _itemID Marketplace ID of item for sale
   */
  function toggleForSale(uint256 _itemID) external;

  /**
   * @dev Returns an array of all items for sale on marketplace
   *
   * note This is from the clone OpenSea tutorial, but I modified it to be
   * slimmer, lighter, and easier to understand.
   *
   */
  function getItemsForSale() external view returns (MarketItem[] memory);

  /**
   * @dev Getter function for all itemIDs with forSale. This function should run lighter and faster
   * than getItemsForSale() because it doesn't return structs.
   */
  function getItemIDsForSale() external view returns (uint256[] memory itemIDs);

  /**
   * @dev Returns an array of MarketItem structs given an array of _itemIDs.
   */
  function getMarketItems(uint256[] memory _itemIDs) external view returns (MarketItem[] memory marketItems_);

  /**
   * @dev Checks if an address owns a tokenID from a token contract
   *
   * @param _owner The token owner being checked
   * @param _tokenContract The contract address of the token being checked
   * @param _tokenID The token ID being checked
   */
  function ownsToken(
    address _owner,
    address _tokenContract,
    uint256 _tokenID
  ) external view returns (bool);
}
