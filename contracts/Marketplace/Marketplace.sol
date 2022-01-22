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

  string private errorMsgCallerNotAdmin;
  string private errorMsgAddressAlreadyAdmin;
  string private errorMsgAddressNotAdmin;

  // Used by noReentrantCalls
  address internal msgSender;
  uint256 private constant notEntered = 1;
  uint256 private constant entered = 2;
  uint256 private status;

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
    address blacklistedAddress,
    address indexed adminAddress,
    string memo,
    uint256 timestamp
  );
  event AddressWhitelisted(
    address whitelistedAddress,
    address indexed adminAddress,
    string memo,
    uint256 timestamp
  );

  constructor(address[] memory _adminAddresses) {
    for (uint256 i = 0; i < _adminAddresses.length; i++) {
      isAdmin[_adminAddresses[i]] = true;
    }
    msgSender = address(this);
    status = notEntered;
    errorMsgCallerNotAdmin = "Marketplace: Caller is not admin";
    errorMsgAddressAlreadyAdmin = "Marketplace: Address is already an admin";
    errorMsgAddressNotAdmin = "Marketplace: Address is not an admin";
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
  // Emits AdminAdded event
  function addAdmin(address _newAddress, string calldata _memo) external onlyAdmin returns (bool) {
    require(!isAdmin[_newAddress], errorMsgAddressAlreadyAdmin);

    isAdmin[_newAddress] = true;

    emit AdminAdded(_newAddress, tx.origin, _memo, block.timestamp);
    return true;
  }

  // Adds an address to isItemAdmin mapping
  // Emits ItemAdminAdded event
  function addItemAdmin(
    uint256 _itemID,
    address _newAddress,
    string calldata _memo
  ) external onlyItemAdmin(_itemID) returns (bool) {
    require(isItemAdmin[_itemID][msg.sender] && isItemAdmin[_itemID][tx.origin], errorMsgCallerNotAdmin);
    require(!isItemAdmin[_itemID][_newAddress], errorMsgAddressAlreadyAdmin);

    isItemAdmin[_itemID][_newAddress] = true;

    emit ItemAdminAdded(_itemID, _newAddress, _msgSender(), _memo, block.timestamp);
    return true;
  }

  // Removes an address from isAdmin mapping
  // Emits AdminRemoved event
  function removeAdmin(address _oldAddress, string calldata _memo) external onlyAdmin returns (bool) {
    require(isAdmin[_oldAddress], errorMsgAddressNotAdmin);

    isAdmin[_oldAddress] = false;

    emit AdminRemoved(_oldAddress, tx.origin, _memo, block.timestamp);
    return true;
  }

  // Removes an address from isItemAdmin mapping
  // Emits ItemAdminRemoved event
  function removeItemAdmin(
    uint256 _itemID,
    address _oldAddress,
    string calldata _memo
  ) external onlyItemAdmin(_itemID) returns (bool) {
    require(isItemAdmin[_itemID][msg.sender] && isItemAdmin[_itemID][tx.origin], errorMsgCallerNotAdmin);
    require(isItemAdmin[_itemID][_oldAddress], errorMsgAddressNotAdmin);
    require(itemCreator[_itemID] == _msgSender(), "Cannot remove item creator");

    isItemAdmin[_itemID][_oldAddress] = false;

    emit ItemAdminRemoved(_itemID, _oldAddress, _msgSender(), _memo, block.timestamp);
    return true;
  }

  /**
   * @notice Toggles isBlacklisted for an address. Can only be called by Pazari
   * Marketplace admins. Other contracts that implement address blacklisting
   * can call this contract's isBlacklisted mapping.
   *
   * @param _userAddress Address of user being black/whitelisted
   * @param _memo Provide contextual info/code for why user was black/whitelisted
   *
   * @dev Emits AddressBlacklisted event when _userAddress is blacklisted
   * @dev Emits AddressWhitelisted event when _userAddress is whitelisted
   */
  function toggleBlacklist(address _userAddress, string calldata _memo) external returns (bool) {
    require(isAdmin[msg.sender] && isAdmin[tx.origin], errorMsgCallerNotAdmin);
    require(!isAdmin[_userAddress], "Cannot blacklist admins");

    if (!isBlacklisted[_userAddress]) {
      isBlacklisted[_userAddress] = true;
      emit AddressBlacklisted(_userAddress, _msgSender(), _memo, block.timestamp);
    } else {
      isBlacklisted[_userAddress] = false;
      emit AddressWhitelisted(_userAddress, _msgSender(), _memo, block.timestamp);
    }

    return true;
  }

  /**
   * @notice Requires that both msg.sender and tx.origin be admins. This restricts all
   * calls to only Pazari-owned admin addresses, including wallets and contracts, and
   * eliminates phishing attacks.
   */
  modifier onlyAdmin() {
    require(isAdmin[msg.sender] && isAdmin[tx.origin], errorMsgCallerNotAdmin);
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
      errorMsgCallerNotAdmin
    );
    _;
  }

  /**
   * @notice Provides defense against reentrancy calls
   * @dev msgSender is only used to avoid needless function calls, and
   * isn't part of the reentrancy guard. It is set back to this address
   * after every use to refund some of the gas spent on it.
   */
  modifier noReentrantCalls() {
    require(status == notEntered, "Reentrancy not allowed");
    status = entered; // Lock function
    msgSender = _msgSender(); // Store value of _msgSender()
    _;
    msgSender = address(this); // Reset msgSender
    status = notEntered; // Unlock function
  }
}


contract Marketplace is ERC1155Holder, AccessControlMP {
  using Counters for Counters.Counter;

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
  event MarketItemSold(uint256 indexed itemID, uint256 amount, address owner);

  // Fires when a MarketItem's last token is bought
  event ItemSoldOut(uint256 indexed itemID);

  // Fires when a creator restocks MarketItems that are sold out
  event ItemRestocked(uint256 indexed itemID, uint256 amount);

  // Fires when a creator pulls a MarketItem's stock from the Marketplace
  event ItemPulled(uint256 indexed itemID, uint256 amount);

  // Fires when forSale is toggled on or off for an itemID
  event ForSaleToggled(uint256 indexed itemID, bool forSale);

  // Fires when a MarketItem has been deleted
  event MarketItemDeleted(uint256 itemID, address indexed itemAdmin, uint256 timestamp);

  // Fires when market item details are modified
  event MarketItemChanged(
    uint256 indexed itemID,
    uint256 price,
    address paymentContract,
    bool isPush,
    bytes32 routeID,
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

  // Checks if an item was deleted or if _itemID is valid
  modifier itemExists(uint256 _itemID) {
    MarketItem memory item = marketItems[_itemID - 1];
    require(item.itemID == _itemID, "Item was deleted");
    require(_itemID <= marketItems.length, "Invalid itemID");
    _;
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
  ) external noReentrantCalls noBlacklist returns (uint256 itemID) {
    MarketItem memory item = MarketItem({
      itemID: itemID,
      tokenContract: _tokenContract,
      tokenID: _tokenID,
      amount: _amount,
      price: _price,
      paymentContract: _paymentContract,
      isPush: _isPush,
      routeID: _routeID,
      routeMutable: _routeMutable,
      forSale: _forSale,
      itemLimit: _itemLimit
    });
    /* ========== CHECKS ========== */
    require(tokenMap[_tokenContract][_tokenID] == 0, "Item already exists");
    require(_paymentContract != address(0), "Invalid payment token contract address");
    (, , , bool isActive) = iPaymentRouter.paymentRouteID(_routeID);
    require(isActive, "Payment route inactive");

    // If _amount == 0, then move entire token balance to Marketplace
    if (_amount == 0) {
      item.amount = IERC1155(item.tokenContract).balanceOf(msgSender, item.tokenID);
    }

    /* ========== EFFECTS ========== */

    // Store MarketItem data
    itemID = _createMarketItem(item);

    /* ========== INTERACTIONS ========== */

    // Transfer tokens from seller to Marketplace
    IERC1155(_tokenContract).safeTransferFrom(_msgSender(), address(this), item.tokenID, item.amount, "");

    // Check that Marketplace's internal balance matches the token's balanceOf() value
    item = marketItems[itemID - 1];
    require(
      IERC1155(item.tokenContract).balanceOf(address(this), item.tokenID) >= item.amount,
      "Market received insufficient tokens"
    );
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
  ) external noReentrantCalls noBlacklist returns (uint256 itemID) {
    MarketItem memory item = MarketItem({
      itemID: itemID,
      tokenContract: _tokenContract,
      tokenID: _tokenID,
      amount: _amount,
      price: _price,
      paymentContract: _paymentContract,
      isPush: true,
      routeID: _routeID,
      routeMutable: false,
      forSale: true,
      itemLimit: 1
    });

    /* ========== CHECKS ========== */
    require(tokenMap[_tokenContract][_tokenID] == 0, "Item already exists");
    require(_paymentContract != address(0), "Invalid payment token contract address");
    (, , , bool isActive) = iPaymentRouter.paymentRouteID(_routeID);
    require(isActive, "Payment route inactive");

    // If _amount == 0, then move entire token balance to Marketplace
    if (_amount == 0) {
      item.amount = IERC1155(_tokenContract).balanceOf(_msgSender(), _tokenID);
    }

    /* ========== EFFECTS ========== */

    // Store MarketItem data
    itemID = _createMarketItem(item);

    /* ========== INTERACTIONS ========== */

    // Transfer tokens from seller to Marketplace
    IERC1155(_tokenContract).safeTransferFrom(_msgSender(), address(this), _tokenID, item.amount, "");

    // Check that Marketplace's internal balance matches the token's balanceOf() value
    item = marketItems[itemID - 1];
    require(
      IERC1155(item.tokenContract).balanceOf(address(this), item.tokenID) >= item.amount,
      "Market did not receive tokens"
    );
  }

  /**
   * @dev Private function that updates internal variables and storage for a new MarketItem
   */
  function _createMarketItem(MarketItem memory item) private returns (uint256 itemID) {
    // If itemLimit == 0, then there is no itemLimit, use type(uint256).max to make itemLimit infinite
    if (item.itemLimit == 0) {
      item.itemLimit = type(uint256).max;
    }
    // If price == 0, then the item is free and only one copy can be owned
    if (item.price == 0) {
      item.itemLimit = 1;
    }

    // Define itemID
    itemID = marketItems.length + 1;
    // Update local variable's itemID
    item.itemID = itemID;
    // Push local variable to marketItems[]
    marketItems.push(item);
    
    // Push itemID to sellersMarketItems mapping array
    sellersMarketItems[msgSender].push(item.itemID);

    // Assign itemID to tokenMap mapping
    tokenMap[item.tokenContract][item.tokenID] = itemID;

    // Assign isItemAdmin and itemCreator to msgSender()
    itemCreator[itemID] = msgSender;
    isItemAdmin[itemID][msgSender] = true;

    // Emits MarketItemCreated event
    emit MarketItemCreated(
      itemID,
      item.tokenContract,
      item.tokenID,
      msgSender,
      item.price,
      item.amount,
      item.paymentContract
    );
  }
  
  /**
   * @dev Purchases an _amount of market item itemID
   *
   * @param _itemID Market ID of item being bought
   * @param _amount Amount of item itemID being purchased (MVP: 1)
   * @return bool Success boolean
   *
   * @dev Emits ItemSoldOut event
   *
   * note Providing _amount == 0 will purchase the item's full itemLimit
   * minus the buyer's existing balance.
   */
  function buyMarketItem(uint256 _itemID, uint256 _amount)
    external
    noReentrantCalls
    noBlacklist
    itemExists(_itemID)
    returns (bool)
  {
    // Pull data from itemID's MarketItem struct
    MarketItem memory item = marketItems[_itemID - 1];
    uint256 itemLimit = item.itemLimit;
    uint256 balance = IERC1155(item.tokenContract).balanceOf(_msgSender(), item.tokenID);
    uint256 initBuyersBalance = IERC1155(item.tokenContract).balanceOf(msgSender, item.tokenID);

    // Define total cost of purchase
    uint256 totalCost = item.price * _amount;

    /* ========== CHECKS ========== */
    require(
      !isItemAdmin[item.itemID][_msgSender()] || itemCreator[item.itemID] != _msgSender(),
      "Can't buy your own item"
    );
    require(item.amount > 0, "Item sold out");
    require(item.forSale, "Item not for sale");
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

    require( // Buyer should be + _amount
      IERC1155(item.tokenContract)
      .balanceOf(msgSender, item.tokenID) == initBuyersBalance + _amount,
      "Buyer never received token"
    );

    emit MarketItemSold(item.itemID, _amount, msgSender);
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
    noReentrantCalls
    noBlacklist
    onlyItemAdmin(_itemID)
    itemExists(_itemID)
    returns (bool)
  {
    MarketItem memory item = marketItems[_itemID - 1];
    uint256 initMarketBalance = IERC1155(item.tokenContract).balanceOf(address(this), item.tokenID);

    /* ========== CHECKS ========== */
    require(
      IERC1155(item.tokenContract).balanceOf(_msgSender(), item.tokenID) >= _amount,
      "Insufficient token balance"
    );

    /* ========== EFFECTS ========== */
    // If item is out of stock
    if (item.amount == 0) {
      itemsSoldOut.decrement();
      item.forSale = true;
    }

    item.amount += _amount;
    marketItems[_itemID - 1] = item; // Update actual market item

    /* ========== INTERACTIONS ========== */
    IERC1155(item.tokenContract).safeTransferFrom(_msgSender(), address(this), item.tokenID, _amount, "");

    // Check that balances updated correctly on both sides
    require( // Marketplace should be + _amount
      IERC1155(item.tokenContract)
      .balanceOf(address(this), item.tokenID) == initMarketBalance + _amount,
      "Marketplace never received tokens"
    );

    emit ItemRestocked(_itemID, _amount);
    return true;
  }

  /**
   * @notice Removes _amount of item tokens for _itemID and transfers back to seller's wallet
   *
   * @param _itemID MarketItem's ID
   * @param _amount Amount of tokens being pulled from Marketplace, 0 == pull all tokens
   * @return bool Success bool
   *
   * @dev Emits ItemPulled event
   */
  function pullStock(uint256 _itemID, uint256 _amount)
    external
    noReentrantCalls
    noBlacklist
    onlyItemAdmin(_itemID)
    itemExists(_itemID)
    returns (bool)
  {
    MarketItem memory item = marketItems[_itemID - 1];
    uint256 initMarketBalance = item.amount;

    /* ========== CHECKS ========== */
    // Store initial values
    require(item.amount >= _amount, "Not enough inventory to pull");

    // Pulls all remaining tokens if _amount == 0, sets forSale to false
    if (_amount == 0 || _amount >= item.amount) {
      _amount = item.amount;
      marketItems[_itemID - 1].forSale = false;
      itemsSoldOut.increment();
    }

    /* ========== EFFECTS ========== */
    marketItems[_itemID - 1].amount -= _amount;

    /* ========== INTERACTIONS ========== */
    IERC1155(item.tokenContract).safeTransferFrom(address(this), _msgSender(), item.tokenID, _amount, "");

    // Check that balances updated correctly on both sides
    require( // Marketplace should be - _amount
      IERC1155(item.tokenContract).balanceOf(address(this), item.tokenID) == initMarketBalance - _amount,
      "Marketplace never lost tokens"
    );

    emit ItemPulled(_itemID, _amount);
    return true;
  }

  /**
   * @notice Function that allows item creator to change price, accepted payment
   * token, whether token uses push or pull routes, and payment route.
   *
   * @param _itemID Market item ID
   * @param _price Market price in stablecoins
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
    uint256 _itemLimit,
    bool _forSale
  ) external 
    noReentrantCalls 
    noBlacklist 
    onlyItemAdmin(_itemID) 
    itemExists(_itemID) 
    returns (bool) 
  {
    MarketItem memory oldItem = marketItems[_itemID - 1];
    // routeMutable logic
    if (!oldItem.routeMutable || _routeID == 0) {
      // If the payment route is not mutable, then set the input equal to the old routeID
      _routeID = oldItem.routeID;
    }
    // itemLimit special condition logic
    // If itemLimit == 0, then there is no itemLimit, use type(uint256).max to make itemLimit infinite
    if (_itemLimit == 0) {
      _itemLimit = type(uint256).max;
    }  

    // Toggle forSale logic
    if ((oldItem.forSale != _forSale) && (_forSale == false)) {
      itemsSoldOut.increment();
      emit ForSaleToggled(_itemID, _forSale);
    } else if ((oldItem.forSale != _forSale) && (_forSale == true)) {
      require(oldItem.amount > 0, "Restock item before reactivating");
      itemsSoldOut.decrement();
      emit ForSaleToggled(_itemID, _forSale);
    }

    // Modify MarketItem within marketItems array
    marketItems[_itemID - 1] = MarketItem({
      itemID: _itemID,
      tokenContract: oldItem.tokenContract,
      tokenID: oldItem.tokenID,
      amount: oldItem.amount,
      price: _price,
      paymentContract: _paymentContract,
      isPush: _isPush,
      routeID: _routeID,
      routeMutable: oldItem.routeMutable,
      forSale: _forSale,
      itemLimit: _itemLimit
    });

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
   *
   * @dev Emits ForSaleToggled event
   */
/* 
  function toggleForSale(uint256 _itemID)
    external
    noReentrantCalls
    noBlacklist
    onlyItemAdmin(_itemID)
    itemExists(_itemID)
    returns (bool forSale)
  {
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
*/

  /**
   * @notice Deletes a MarketItem, setting all its properties to default values
   * @dev Does not remove itemID or the entry in marketItems, just sets properties to default
   * and removes tokenMap mappings. This frees up the tokenID to be used in a new MarketItem.
   * @dev Only the itemCreator or a Pazari admin can call this function
   *
   * @dev Emits MarketItemDeleted event
   */
  function deleteMarketItem(uint256 _itemID) 
    external 
    noReentrantCalls 
    noBlacklist 
    itemExists(_itemID) 
    returns (bool) 
  {
    MarketItem memory item = marketItems[_itemID - 1];
    // Caller must either be item's creator or a Pazari admin, no itemAdmins allowed
    require(
      _msgSender() == itemCreator[_itemID] || isAdmin[_msgSender()],
      "Only item creators and Pazari admins"
    );
    // Require item has been completely unstocked and deactivated
    require(!item.forSale, "Deactivate item before deleting");
    require(item.amount == 0, "Pull all stock before deleting");

    // Erase tokenMap mapping, frees up tokenID to be used in a new MarketItem
    delete tokenMap[item.tokenContract][item.tokenID];
    // Set all properties to defaults by deletion
    delete marketItems[_itemID - 1];
    // Erase itemCreator mapping
    delete itemCreator[_itemID];
    // Erase sellersMarketItems entry

    // RETURN
    emit MarketItemDeleted(_itemID, _msgSender(), block.timestamp);
    return true;
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
   * @notice Returns an array of MarketItems created by the seller's address
   * @dev Used for displaying seller's items for mini-shops on seller profiles
   * @dev There is no way to remove items from this array, and deleted itemIDs will still show,
   * but will have nonexistent item details.
   */
  function getSellersMarketItems(address _sellerAddress) public view returns (uint256[] memory) {
    return sellersMarketItems[_sellerAddress];
  }

  /**
   * @notice This is in case someone mistakenly sends their ERC1155 NFT to this contract address
   * @dev Requires both tx.origin and msg.sender be admins
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
  ) external noReentrantCalls returns (bool) {
    uint256 itemID = tokenMap[_nftContract][_tokenID];
    uint256 initMarketBalance = IERC1155(_nftContract).balanceOf(address(this), _tokenID);
    uint256 initOwnerBalance = IERC1155(_nftContract).balanceOf(_recipient, _tokenID);
    uint256 marketItemBalance = marketItems[itemID - 1].amount;

    require(initMarketBalance > marketItemBalance, "No tokens available");
    require(isAdmin[tx.origin] && isAdmin[msg.sender], "Please contact Pazari support about your lost NFT");

    // If _amount is greater than the amount of unlisted tokens
    if (_amount > initMarketBalance - marketItemBalance) {
      // Set _amount equal to unlisted tokens
      _amount = initMarketBalance - marketItemBalance;
    }

    // Transfer token(s) to recipient
    IERC1155(_nftContract).safeTransferFrom(address(this), _recipient, _tokenID, _amount, "");

    // Check that recipient's balance was updated correctly
    require( // Recipient final balance should be initial + _amount
      IERC1155(_nftContract).balanceOf(_recipient, _tokenID) == initOwnerBalance + _amount,
      "Recipient never received token(s)"
    );

    emit NFTRecovered(_nftContract, _tokenID, _recipient, msgSender, _memo, block.timestamp);
    return true;
  }
}
