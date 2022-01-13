// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Dependencies/Counters.sol";
import "../Dependencies/IERC20Metadata.sol";
import "../Dependencies/ERC1155Holder.sol";
import "../Dependencies/IERC1155.sol";
import "../Dependencies/Context.sol";
import "../PaymentRouter/IPaymentRouter.sol";
import "../Tokens/IPazariTokenMVP.sol";

contract AccessControlMP {
  // Maps admin addresses to bool
  mapping(address => bool) public isAdmin;

  // Maps itemIDs and admin addresses to bool
  mapping(uint256 => mapping(address => bool)) public isItemAdmin;

  // Mapping of all blacklisted addresses that are banned from Pazari Marketplace
  mapping(address => bool) public isBlacklisted;

  // Maps itemID to the address that created it
  mapping(uint256 => address) public itemCreator;

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

  constructor(address[] memory _adminAddresses) {
    for (uint256 i = 0; i < _adminAddresses.length; i++) {
      isAdmin[_adminAddresses[i]] = true;
    }
  }

  /**
   * @notice Returns tx.origin for any Pazari-owned admin contracts, returns msg.sender
   * for everything else. See PaymentRouter for more details.
   */
  function _msgSender() public view returns (address) {
    if (tx.origin != msg.sender && isAdmin[msg.sender]) {
      return tx.origin;
    } else return msg.sender;
  }

  // Adds an address to isAdmin mapping
  function addAdmin(address _newAddress, string memory _memo) external onlyAdmin returns (bool) {
    require(!isAdmin[_newAddress], "Address is already an admin");

    isAdmin[_newAddress] = true;

    emit AdminAdded(_newAddress, tx.origin, _memo, block.timestamp);
    return true;
  }

  // Adds an address to isItemAdmin mapping
  function addItemAdmin(
    uint256 _itemID,
    address _newAddress,
    string memory _memo
  ) external onlyItemAdmin(_itemID) returns (bool) {
    require(isItemAdmin[_itemID][msg.sender] && isItemAdmin[_itemID][tx.origin], "Caller is not admin");
    require(!isItemAdmin[_itemID][_newAddress], "Address is already an item admin");

    isItemAdmin[_itemID][_newAddress] = true;

    emit ItemAdminAdded(_itemID, _newAddress, _msgSender(), _memo, block.timestamp);
    return true;
  }

  // Removes an address from isAdmin mapping
  function removeAdmin(address _oldAddress, string memory _memo) external onlyAdmin returns (bool) {
    require(isAdmin[_oldAddress], "Address is not an admin");

    isAdmin[_oldAddress] = false;

    emit AdminRemoved(_oldAddress, tx.origin, _memo, block.timestamp);
    return true;
  }

  // Removes an address from isItemAdmin mapping
  function removeItemAdmin(
    uint256 _itemID,
    address _oldAddress,
    string memory _memo
  ) external onlyItemAdmin(_itemID) returns (bool) {
    require(isItemAdmin[_itemID][msg.sender] && isItemAdmin[_itemID][tx.origin], "Caller is not admin");
    require(isItemAdmin[_itemID][_oldAddress], "Address is not an admin");
    require(itemCreator[_itemID] == _msgSender(), "Cannot remove item creator");

    isItemAdmin[_itemID][_oldAddress] = false;

    emit ItemAdminRemoved(_itemID, _oldAddress, _msgSender(), _memo, block.timestamp);
    return true;
  }

  /**
   * @notice Toggles isBlacklisted for an address. Can only be called by Pazari
   * Marketplace admins. Other contracts that implement address blacklisting
   * can call this contract's isBlacklisted mapping.
   */
  function toggleBlacklist(address _listedAddress, string memory _memo) external returns (bool) {
    require(isAdmin[msg.sender] && isAdmin[tx.origin], "Only Pazari admin");
    require(!isAdmin[_listedAddress], "Cannot blacklist admins");

    if (!isBlacklisted[_listedAddress]) {
      isBlacklisted[_listedAddress] = true;
      emit AddressBlacklisted(_listedAddress, _msgSender(), _memo, block.timestamp);
    } else {
      isBlacklisted[_listedAddress] = false;
      emit AddressWhitelisted(_listedAddress, _msgSender(), _memo, block.timestamp);
    }

    return true;
  }

  /**
   * @notice Requires that both msg.sender and tx.origin be admins. This restricts all
   * calls to only Pazari-owned admin addresses, including wallets and contracts, and
   * eliminates phishing attacks.
   */
  modifier onlyAdmin() {
    require(isAdmin[msg.sender] && isAdmin[tx.origin], "Only Pazari-owned addresses");
    _;
  }

  modifier noBlacklist() {
    require(!isBlacklisted[_msgSender()], "Caller cannot be blacklisted");
    _;
  }

  // Restricts access to admins of a MarketItem
  modifier onlyItemAdmin(uint256 _itemID) {
    require(
      itemCreator[_itemID] == _msgSender() || isItemAdmin[_itemID][_msgSender()] || isAdmin[_msgSender()],
      "Caller is neither admin nor item creator"
    );
    _;
  }
}

contract Marketplace is ERC1155Holder, AccessControlMP {
  using Counters for Counters.Counter;

  // Fires when a new MarketItem is created;
  event MarketItemCreated(
    uint256 indexed itemID,
    address indexed nftContract,
    uint256 indexed tokenID,
    address admin,
    uint256 price,
    uint256 amount,
    address paymentToken
  );

  // Fires when a MarketItem is sold;
  event MarketItemSold(uint256 indexed itemID, uint256 amount, address owner);

  // Fires when a MarketItem's last token is bought
  event ItemSoldOut(uint256 indexed itemID);

  // Fires when a creator restocks MarketItems that are sold out
  event ItemRestocked(uint256 indexed itemID, uint256 amount);

  // Fires when a creator pulls a MarketItem's stock from the Marketplace
  event ItemPulled(uint256 itemID, uint256 amount);

  // Fires when forSale is toggled on or off for an itemID
  event ForSaleToggled(uint256 itemID, bool forSale);

  // Fires when market item details are modified
  event MarketItemChanged(
    uint256 itemID,
    uint256 price,
    address paymentContract,
    bool isPush,
    bytes32 routeID,
    uint256 itemLimit
  );

  // Maps a seller's address to an array of all itemIDs they have created
  // seller's address => itemIDs
  mapping(address => uint256[]) public sellersMarketItems;

  // Maps a contract's address and a token's ID to its corresponding itemId
  // The purpose of this is to prevent duplicate items for same token
  // tokenContract address + tokenID => itemID
  mapping(address => mapping(uint256 => uint256)) public tokenMap;

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

  // Counter for items with forSale == false
  Counters.Counter private itemsSoldOut;

  // Array of all MarketItems ever created
  MarketItem[] public marketItems;

  // Address of PaymentRouter contract
  IPaymentRouter public immutable iPaymentRouter;

  constructor(address _paymentRouter, address[] memory _admins) AccessControlMP(_admins) {
    //Connect to payment router contract
    iPaymentRouter = IPaymentRouter(_paymentRouter);
  }

  /**
   * @notice Creates a MarketItem struct and assigns it an itemID
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
   * @return itemID ItemID of the market item
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
  ) external noBlacklist returns (uint256 itemID) {
    /* ========== CHECKS ========== */
    require(tokenMap[_tokenContract][_tokenID] == 0, "Item already exists");
    require(_paymentContract != address(0), "Invalid payment token contract address");
    (, , , bool isActive) = iPaymentRouter.paymentRouteID(_routeID);
    require(isActive, "Payment route inactive");

    // If _amount == 0, then move entire token balance to Marketplace
    if (_amount == 0) {
      _amount = IERC1155(_tokenContract).balanceOf(_msgSender(), _tokenID);
    }

    /* ========== EFFECTS ========== */

    // Store MarketItem data
    itemID = _createMarketItem(
      _tokenContract,
      _tokenID,
      _amount,
      _price,
      _paymentContract,
      _isPush,
      _forSale,
      _routeID,
      _itemLimit,
      _routeMutable
    );

    /* ========== INTERACTIONS ========== */

    // Transfer tokens from seller to Marketplace
    IERC1155(_tokenContract).safeTransferFrom(_msgSender(), address(this), _tokenID, _amount, "");

    // Check that Marketplace's internal balance matches the token's balanceOf() value
    MarketItem memory item = marketItems[itemID - 1];
    assert(IERC1155(item.tokenContract).balanceOf(address(this), item.tokenID) == item.amount);
  }

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
  ) external noBlacklist returns (uint256 itemID) {
    /* ========== CHECKS ========== */
    require(tokenMap[_tokenContract][_tokenID] == 0, "Item already exists");
    require(_paymentContract != address(0), "Invalid payment token contract address");
    (, , , bool isActive) = iPaymentRouter.paymentRouteID(_routeID);
    require(isActive, "Payment route inactive");

    // If _amount == 0, then move entire token balance to Marketplace
    if (_amount == 0) {
      _amount = IERC1155(_tokenContract).balanceOf(_msgSender(), _tokenID);
    }

    /* ========== EFFECTS ========== */

    // Store MarketItem data
    itemID = _createMarketItem(
      _tokenContract,
      _tokenID,
      _amount,
      _price,
      _paymentContract,
      true,
      true,
      _routeID,
      1,
      false
    );

    /* ========== INTERACTIONS ========== */

    // Transfer tokens from seller to Marketplace
    IERC1155(_tokenContract).safeTransferFrom(_msgSender(), address(this), _tokenID, _amount, "");

    // Check that Marketplace's internal balance matches the token's balanceOf() value
    MarketItem memory item = marketItems[itemID - 1];
    assert(IERC1155(item.tokenContract).balanceOf(address(this), item.tokenID) == item.amount);
  }

  /**
   * @dev Private function that updates internal variables and storage for a new MarketItem
   */
  function _createMarketItem(
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
  ) private returns (uint256 itemID) {
    // If itemLimit == 0, then there is no itemLimit, use type(uint256).max to make itemLimit infinite
    if (_itemLimit == 0) {
      _itemLimit = type(uint256).max;
    }
    // If price == 0, then the item is free and only one copy can be owned
    if (_price == 0) {
      _itemLimit = 1;
    }

    // Add + 1 so itemID 0 will never exist and can be used for checks
    // Just remember to use [itemID - 1] when accessing marketItems[]
    itemID = marketItems.length + 1;

    // Store new MarketItem in local variable
    MarketItem memory item = MarketItem(
      itemID,
      _tokenContract,
      _tokenID,
      _amount,
      _price,
      _paymentContract,
      _isPush,
      _routeID,
      _routeMutable,
      _forSale,
      _itemLimit
    );

    // Assign isItemAdmin and itemCreator to _msgSender()
    isItemAdmin[itemID][_msgSender()] = true;
    itemCreator[itemID] = _msgSender();
    // Pushes MarketItem to marketItems[]
    marketItems.push(item);

    // Push itemID to sellersMarketItems mapping array
    // _msgSender == sellerAddress
    sellersMarketItems[_msgSender()].push(item.itemID);

    // Assign itemID to tokenMap mapping
    tokenMap[_tokenContract][_tokenID] = itemID;

    // Emits MarketItemCreated event
    // _msgSender == sellerAddress
    emit MarketItemCreated(itemID, _tokenContract, _tokenID, _msgSender(), _price, _amount, _paymentContract);
  }

  /**
   * @dev Purchases an _amount of market item itemID
   *
   * @param _itemID Market ID of item being bought
   * @param _amount Amount of item itemID being purchased (MVP: 1)
   * @return bool Success boolean
   *
   * note Providing _amount == 0 will purchase the item's full itemLimit.
   */
  function buyMarketItem(uint256 _itemID, uint256 _amount) external noBlacklist returns (bool) {
    // Pull data from itemID's MarketItem struct
    MarketItem memory item = marketItems[_itemID - 1];
    uint256 balance = IERC1155(item.tokenContract).balanceOf(_msgSender(), item.tokenID);
    uint256 itemLimit = item.itemLimit;

    // Define total cost of purchase
    uint256 totalCost = item.price * _amount;

    /* ========== CHECKS ========== */
    require(_itemID <= marketItems.length, "Item does not exist");
    require(item.forSale, "Item not for sale");
    require(item.amount > 0, "Item sold out");
    require(!isItemAdmin[item.itemID][_msgSender()], "Can't buy your own item");
    require(balance < itemLimit, "Buyer already owns the item limit");
    // If _amount == 0, then purchase itemLimit - balance
    // If _amount + balance surpasses itemLimit, then purchase itemLimit - balance
    if (_amount == 0 || _amount + balance > itemLimit) {
      _amount = itemLimit - balance;
    }

    /* ========== EFFECTS ========== */
    // If buy order exceeds all available stock, then:
    if (item.amount <= _amount) {
      itemsSoldOut.increment(); // Increment counter variable for items sold out
      _amount = item.amount; // Set _amount to the item's remaining inventory
      marketItems[_itemID - 1].forSale = false; // Take item off the market
      emit ItemSoldOut(item.itemID); // Emit itemSoldOut event
    }

    // Adjust Marketplace's inventory
    marketItems[_itemID - 1].amount -= _amount;
    // Emit MarketItemSold
    emit MarketItemSold(item.itemID, _amount, _msgSender());

    /* ========== INTERACTIONS ========== */
    require(IERC20(item.paymentContract).approve(address(this), totalCost), "ERC20 approval failure");

    // Pull payment tokens from msg.sender to Marketplace
    require(
      IERC20(item.paymentContract).transferFrom(_msgSender(), address(this), totalCost),
      "ERC20 transfer failure"
    );

    // Approve payment tokens for transfer to PaymentRouter
    require(
      IERC20(item.paymentContract).approve(address(iPaymentRouter), totalCost),
      "ERC20 approval failure"
    );

    // Send ERC20 tokens through PaymentRouter, isPush determines which function is used
    // note PaymentRouter functions make external calls to ERC20 contracts, thus they are interactions
    item.isPush
      ? iPaymentRouter.pushTokens(item.routeID, item.paymentContract, address(this), totalCost) // Pushes tokens to recipients
      : iPaymentRouter.holdTokens(item.routeID, item.paymentContract, address(this), totalCost); // Holds tokens for pull collection

    // Call market item's token contract and transfer token from Marketplace to buyer
    IERC1155(item.tokenContract).safeTransferFrom(address(this), _msgSender(), item.tokenID, _amount, "");

    //assert(IERC1155(item.tokenContract).balanceOf(address(this), item.tokenID) == item.amount);
    return true;
  }

  /**
   * @dev Transfers more stock to a MarketItem, requires minting more tokens first and setting
   * approval for Marketplace
   *
   * @param _itemID MarketItem ID
   * @param _amount Amount of tokens being restocked
   *
   * @dev Emits ItemRestocked event
   */
  function restockItem(uint256 _itemID, uint256 _amount)
    external
    noBlacklist
    onlyItemAdmin(_itemID)
    returns (bool)
  {
    /* ========== CHECKS ========== */
    MarketItem memory item = marketItems[_itemID - 1];
    require(marketItems.length >= _itemID, "MarketItem does not exist");
    require(
      IERC1155(item.tokenContract).balanceOf(_msgSender(), item.tokenID) >= _amount,
      "Insufficient token balance"
    );

    /* ========== EFFECTS ========== */
    marketItems[_itemID - 1].amount += _amount;
    emit ItemRestocked(_itemID, _amount);

    /* ========== INTERACTIONS ========== */
    IERC1155(item.tokenContract).safeTransferFrom(_msgSender(), address(this), item.tokenID, _amount, "");

    assert(
      IERC1155(item.tokenContract).balanceOf(address(this), item.tokenID) == marketItems[_itemID - 1].amount
    );
    return true;
  }

  /**
   * @notice Removes _amount of item tokens for _itemID and transfers back to seller's wallet
   *
   * @param _itemID MarketItem's ID
   * @param _amount Amount of tokens being pulled from Marketplace, 0 == pull all tokens
   *
   * @dev Emits StockPulled event
   */
  function pullStock(uint256 _itemID, uint256 _amount)
    external
    noBlacklist
    onlyItemAdmin(_itemID)
    returns (bool)
  {
    /* ========== CHECKS ========== */
    // itemID will always be <= marketItems.length, but cannot be > marketItems.length
    require(_itemID <= marketItems.length, "MarketItem does not exist");
    // Store initial values
    MarketItem memory item = marketItems[_itemID - 1];
    require(item.amount >= _amount, "Not enough inventory to pull");

    // Pulls all remaining tokens if _amount == 0
    if (_amount == 0) {
      _amount = item.amount;
    }

    /* ========== EFFECTS ========== */
    marketItems[_itemID - 1].amount -= _amount;

    /* ========== INTERACTIONS ========== */
    IERC1155(item.tokenContract).safeTransferFrom(address(this), _msgSender(), item.tokenID, _amount, "");

    emit ItemPulled(_itemID, _amount);

    // Assert internal balances updated correctly, item.amount was initial amount
    assert(marketItems[_itemID - 1].amount < item.amount);
    return true;
  }

  /**
   * @dev Function that allows item creator to change price, accepted payment
   * token, whether token uses push or pull routes, and payment route.
   *
   * @param _itemID Market item ID
   * @param _price Market price in stablecoins (_price == 0 => _itemLimit = 1)
   * @param _paymentContract Contract address of token accepted for payment
   * @param _isPush Tells PaymentRouter to use push or pull function
   * @param _routeID Payment route ID, only mutable if routeMutable == true
   * @param _itemLimit Buyer's purchase limit for item (_itemLimit == 0 => no limit)
   * @return bool Success boolean
   *
   * note What cannot be modified:
   * - Token contract address
   * - Token contract token ID
   * - Seller of market item
   * - RouteID mutability
   * - Item's forSale status
   *
   * note If _itemLimit and price are set to 0, then price stays at 0 but _itemLimit
   * is set to 1.
   */
  function modifyMarketItem(
    uint256 _itemID,
    uint256 _price,
    address _paymentContract,
    bool _isPush,
    bytes32 _routeID,
    uint256 _itemLimit
  ) external noBlacklist onlyItemAdmin(_itemID) returns (bool) {
    MarketItem memory oldItem = marketItems[_itemID - 1];
    if (!oldItem.routeMutable || _routeID == 0) {
      // If the payment route is not mutable, then set the input equal to the old routeID
      _routeID = oldItem.routeID;
    }
    // If itemLimit == 0, then there is no itemLimit, use type(uint256).max to make itemLimit infinite
    if (_itemLimit == 0) {
      _itemLimit = type(uint256).max;
    }

    // Modify MarketItem within marketItems array
    marketItems[_itemID - 1] = MarketItem(
      _itemID,
      oldItem.tokenContract,
      oldItem.tokenID,
      oldItem.amount,
      _price,
      _paymentContract,
      _isPush,
      _routeID,
      oldItem.routeMutable,
      oldItem.forSale,
      _itemLimit
    );

    emit MarketItemChanged(_itemID, _price, _paymentContract, _isPush, _routeID, _itemLimit);
    return true;
  }

  /**
   * @dev Toggles whether an item is for sale or not
   *
   * @dev Use this function to activate/deactivate items for sale on market. Only items that are
   * forSale will be returned by getInStockItems().
   *
   * @param _itemID Marketplace ID of item for sale
   * @return forSale True = item reactivated, false = item deactivated
   */
  function toggleForSale(uint256 _itemID) external noBlacklist onlyItemAdmin(_itemID) returns (bool forSale) {
    // Create singleton array for _itemID
    uint256[] memory itemID = new uint256[](1);
    itemID[0] = _itemID;
    MarketItem[] memory item = getMarketItems(itemID);

    if (item[0].forSale) {
      itemsSoldOut.increment();
      marketItems[_itemID - 1].forSale = false;
    } else if (!item[0].forSale) {
      require(item[0].amount > 0, "Restock item before reactivating");
      itemsSoldOut.decrement();
      marketItems[_itemID - 1].forSale = true;
    }

    // Event added
    emit ForSaleToggled(_itemID, marketItems[_itemID - 1].forSale);
    return marketItems[_itemID - 1].forSale;
  }

  /**
   * @dev Returns an array of all items for sale on marketplace
   *
   * note This is from the clone OpenSea tutorial, but I modified it to be
   * slimmer, lighter, and easier to understand.
   *
   */
  function getItemsForSale() public view returns (MarketItem[] memory) {
    // Fetch total item count, both sold and unsold
    uint256 itemCount = marketItems.length;
    // Calculate total unsold items
    uint256 unsoldItemCount = itemCount - itemsSoldOut.current();

    // Create empty array of all unsold MarketItem structs with fixed length unsoldItemCount
    MarketItem[] memory items = new MarketItem[](unsoldItemCount);

    uint256 i; // itemID counter for ALL market items, starts at 1
    uint256 j; // items[] index counter for forSale market items, starts at 0

    // Loop that populates the items[] array
    for (i = 1; j < unsoldItemCount || i <= itemCount; i++) {
      if (marketItems[i - 1].forSale) {
        MarketItem memory unsoldItem = marketItems[i - 1];
        items[j] = unsoldItem; // Assign unsoldItem to items[j]
        j++; // Increment j
      }
    }
    // Return the array of unsold items
    return (items);
  }

  /**
   * @dev Getter function for all itemIDs with forSale. This function should run lighter and faster
   * than getItemsForSale() because it doesn't return structs.
   */
  function getItemIDsForSale() public view returns (uint256[] memory) {
    // Fetch total item count, both sold and unsold
    uint256 itemCount = marketItems.length;
    // Calculate total unsold items
    uint256 unsoldItemCount = itemCount - itemsSoldOut.current();

    // Create empty array of all unsold MarketItem structs with fixed length unsoldItemCount
    uint256[] memory itemIDs = new uint256[](unsoldItemCount);

    uint256 i; // itemID counter for ALL MarketItems
    uint256 j = 0; // itemIDs[] index counter for forSale market items

    for (i = 0; j < unsoldItemCount || i < itemCount; i++) {
      if (marketItems[i].forSale) {
        itemIDs[j] = marketItems[i].itemID; // Assign unsoldItem to items[j]
        j++; // Increment j
      }
    }
    return itemIDs;
  }

  /**
   * @dev Returns an array of MarketItem structs given an arbitrary array of _itemIDs.
   */
  function getMarketItems(uint256[] memory _itemIDs) public view returns (MarketItem[] memory marketItems_) {
    marketItems_ = new MarketItem[](_itemIDs.length);
    for (uint256 i = 0; i < _itemIDs.length; i++) {
      marketItems_[i] = marketItems[_itemIDs[i] - 1];
    }
  }

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
    public
    view
    returns (bool[] memory hasToken)
  {
    hasToken = new bool[](_itemIDs.length);
    for (uint256 i = 0; i < _itemIDs.length; i++) {
      MarketItem memory item = marketItems[_itemIDs[i] - 1];
      if (IERC1155(item.tokenContract).balanceOf(_owner, item.tokenID) != 0) {
        hasToken[i] = true;
      } else hasToken[i] = false;
    }
  }

  /**
   * @notice Returns an array of MarketItems created the seller's address
   * @dev No restrictions for calling this
   */
  function getSellersMarketItems(address _sellerAddress) public view returns (uint256[] memory) {
    return sellersMarketItems[_sellerAddress];
  }

  /**
   * @notice This is in case someone mistakenly sends their ERC1155 NFT to this contract address
   * @dev Requires both tx.origin and msg.sender be admins
   */
  function recoverNFT(
    address _nftContract,
    uint256 _tokenID,
    uint256 _amount
  ) external returns (bool) {
    require(isAdmin[tx.origin] && isAdmin[msg.sender], "Please contact Pazari support about your lost NFT");
    require(IERC1155(_nftContract).balanceOf(address(this), _tokenID) != 0, "NFT not here!");
    uint256 itemID = tokenMap[_nftContract][_tokenID];

    // If tokenID exists as an itemID on pazari, then...
    if (IERC1155(_nftContract).balanceOf(address(this), _tokenID) > marketItems[itemID - 1].amount) {
      // Compare MarketItem.amount to balanceOf, set _amount equal to imbalanced stock
      _amount = IERC1155(_nftContract).balanceOf(address(this), _tokenID) - marketItems[itemID - 1].amount;
    }

    IERC1155(_nftContract).safeTransferFrom(address(this), _msgSender(), _tokenID, _amount, "");
    return true;
  }
}
