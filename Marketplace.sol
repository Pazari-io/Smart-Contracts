/** WORKING VERSION
 * MARKETPLACE EXPERIMENTAL V0.1.3
 *
 * PHOENIX: I like these changes, I'm gonna merge them. I took everything from Experimental and
 * got it working, added missing events, improved the itemID system, and then fixed a revert
 * bug that I caused. All in all, I think it's cleaner.
 * 
 * Differences between Experimental and Experimental2: PLEASE ADD ANYTHING I MISSED
 * - Removed itemIDs as a Counters.Counter variable, itemIDs are assigned by marketItems.length now
 *   - itemIDs are actually (marketItems.length + 1), that way we can use itemID 0 for existence checks
 *   - This means we have to use marketItems[itemID - 1] when accessing MarketItems[]
 * - Added event forSaleToggled(), which is emitted by toggleForSale()
 * - Added event stockPulled(), which is emitted by pullStock()
 * - Fixed bug in createMarketItem() and getItemsForSale() that was throwing revert error
 *   - The problem was marketItems[itemID], which because marketItems was converted to an array we now have to
 *     use marketItems[itemID - 1] to get a MarketItem from marketItems[]
 *   - I may have accidentally caused this bug, so oh well
 * - Changed createMarketItem() and modifyMarketItem() so that if _amount == 0 then the full token balance
 *   will be moved over to Marketplace, which enables front-end to use 0 as an alias for "all stock".
 * - Added MVP default values to comments before external functions
 *
 * Comments: PHOENIX
 * - I commented out _createMarketItem() in constructor function and added + 1 to marketItems.length
 *   inside _createMarketItem(). This avoids itemID 0 while also keeping marketItems.length accurate.
 *   The tradeoff is we have to use marketItems[itemID - 1].
 *
 * - I realized that there is a huge advantage to leaving PaymentRouter (PR) external to Marketplace (MP).
 *   It allows us to deploy expansions for MP without losing any PaymentRoute data, which allows us to
 *   deploy new Pazari contracts that expand functionality in the future without requiring anyone to
 *   set up new PaymentRoutes to use the expanded functionality. However, we need to decide if PR should 
 *   have its external functions permissioned or permissionless. Should only MP contracts be allowed to 
 *   use the PR? Or can anyone? I am afraid leaving PaymentRouter publicly accessible could somehow be 
 *   used to attack us. What happens when a hacker sends stolen crypto down the PaymentRouter and we 
 *   receive a 3%+ cut of it? I think we should make PaymentRouter permissioned access only, and include 
 *   a function/mapping for adding/checking new expansions.
 *
 *
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Dependencies/Counters.sol";
import "../Dependencies/IERC20Metadata.sol";
import "../Dependencies/ERC1155Holder.sol";
import "../Dependencies/IERC1155.sol";
import "../Dependencies/Context.sol";
import "../PaymentRouter/IPaymentRouter.sol";

contract Marketplace is ERC1155Holder, Context {
  using Counters for Counters.Counter;

  // Counter for items with forSale == false
  Counters.Counter private itemsSoldOut;

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

  // Array of all MarketItems ever created
  MarketItem[] public marketItems;

  // Maps a seller's address to an array of all itemIDs they have created
   // seller's address => itemIDs
  mapping(address => uint256[]) public sellersMarketItems;

  // Maps a contract's address and a token's ID to its corresponding itemId
   // The purpose of this is to prevent duplicate items for same token
   // tokenContract address + tokenID => itemID
  mapping(address => mapping(uint256 => uint256)) public tokenMap;

  // Address of PaymentRouter contract
  IPaymentRouter public immutable paymentRouter;

  // Fires when a new MarketItem is created;
  event MarketItemCreated(
    uint256 indexed itemID,
    address indexed nftContract,
    uint256 indexed tokenID,
    address seller,
    uint256 price,
    uint256 amount,
    address paymentToken
  );

  // Fires when a MarketItem is sold;
  event MarketItemSold(uint256 indexed itemID, uint256 amount, address owner);

  // Fires when a creator restocks MarketItems that are sold out
  event ItemRestocked(uint256 indexed itemID, uint256 amount);

  // Fires when a MarketItem's last token is bought
  event ItemSoldOut(uint256 indexed itemID);

  // Fires when forSale is toggled on or off for an itemID
  event forSaleToggled(uint256 itemID, bool forSale);

  // Fires when a creator pulls a MarketItem's stock from the Marketplace
  event stockPulled(uint256 itemID, uint256 amount);
  
  // Fires when market item details are modified
  event MarketItemChanged(
    uint256 itemID,
    uint256 price,
    address paymentContract,
    bool isPush,
    bytes32 routeID,
    uint256 itemLimit
  );

  // Restricts access to the seller of the item
  modifier onlyOwner(uint256 _itemID) {
    require(_itemID < marketItems.length, "Item does not exist");
    require(marketItems[_itemID - 1].owner == _msgSender(), "Unauthorized: Only item owner");
    _;
  }

  constructor(address _paymentRouter) {
    //Connect to payment router contract
    paymentRouter = IPaymentRouter(_paymentRouter);
  }

  /**
   * @dev Creates a MarketItem struct and assigns it an itemID
   *
   * @param _tokenContract Token contract address of the item being sold
   * @param _ownerAddress Owner's address that can pass onlyOwner() (MVP: msg.sender)
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
   * note Front-end must call IERC1155.setApprovalForAll(marketAddress, true) for any ERC1155 token
   * that is NOT a Pazari1155 contract. Pazari1155 will have auto-approval for Marketplace.
   *
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
  ) external returns (uint256 itemID) {

    /* ========== CHECKS ========== */

    require(tokenMap[_tokenContract][_tokenID] == 0, "Item already exists");
    require(_paymentContract != address(0), "Invalid payment token contract address");
    (, , bool isActive) = paymentRouter.paymentRouteID(_routeID);
    require(isActive, "Payment route inactive");

    // If _amount == 0, then move entire token balance to Marketplace
    if (_amount == 0) {
      _amount = IERC1155(_tokenContract).balanceOf(_msgSender(), _tokenID);
    }

    /* ========== EFFECTS ========== */

    // Store MarketItem data
    itemID = _createMarketItem(
      _tokenContract,
      _ownerAddress,
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
   * @dev Private function that updates internal variables and storage for a new MarketItem
   */
  function _createMarketItem(
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
        _ownerAddress,
        _price,
        _paymentContract,
        _isPush,
        _routeID,
        _routeMutable,
        _forSale,
        _itemLimit
     );

    // Pushes MarketItem to marketItems[]
    marketItems.push(item);

    // Push itemID to sellersMarketItems mapping array
    // _msgSender == sellerAddress
    sellersMarketItems[_ownerAddress].push(itemID);

    // Assign itemID to tokenMap mapping
    tokenMap[_tokenContract][_tokenID] = itemID;

    // Emits MarketItemCreated event
    // _msgSender == sellerAddress
    emit MarketItemCreated(
      itemID,
      _tokenContract,
      _tokenID,
      _ownerAddress,
      _price,
      _amount,
      _paymentContract
    );
  }

  /**
   * @dev Purchases an _amount of market item itemID
   *
   * @param _itemID Market ID of item being bought
   * @param _amount Amount of item itemID being purchased (MVP: 1)
   * @return bool Success boolean
   *
   * note Providing _amount == 0 will purchase the item's full itemLimit.
   *
   * note Because PaymentRouter is now external to Marketplace, we have to transfer
   * payment tokens to Marketplace, then approve PaymentRouter to take tokens from
   * Marketplace, and then PaymentRouter transfers tokens from Marketplace to the
   * recipient(s). I want to experiment with approving the payment tokens for use
   * in the PaymentRouter without ever having to transfer them to Marketplace, but
   * for now let's roll with this version for testing.
   */
  function buyMarketItem(uint256 _itemID, uint256 _amount) external returns (bool) {
    // Pull data from itemID's MarketItem struct
    MarketItem memory item = marketItems[_itemID - 1];
    // If _amount == 0, then purchase the itemLimit - balanceOf(buyer)
     // This simplifies logic for purchasing itemLimit on front-end
    if(_amount == 0){
      _amount = item.itemLimit - IERC1155(item.tokenContract).balanceOf(msg.sender, item.tokenID);
    }
    // Define total cost of purchase
    uint256 totalCost = item.price * _amount;


    /* ========== CHECKS ========== */
    require(_itemID <= marketItems.length, "Item does not exist");
    require(item.forSale, "Item not for sale");
    require(item.amount > 0, "Item sold out");
    require(_msgSender() != item.owner, "Can't buy your own item");
    require(
      IERC1155(item.tokenContract).balanceOf(_msgSender(), item.tokenID) + _amount <= item.itemLimit,
      "Purchase exceeds item limit"
    );


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
    IERC20(item.paymentContract).approve(address(this), totalCost);
   
    // Pull payment tokens from msg.sender to Marketplace
    IERC20(item.paymentContract).transferFrom(_msgSender(), address(this), totalCost);

    // Approve payment tokens for transfer to PaymentRouter
    IERC20(item.paymentContract).approve(address(paymentRouter), totalCost);
    
    // Send ERC20 tokens through PaymentRouter, isPush determines which function is used
     // note PaymentRouter functions make external calls to ERC20 contracts, thus they are interactions
    item.isPush
      ? paymentRouter.pushTokens(item.routeID, item.paymentContract, address(this), totalCost) // Pushes tokens to recipients
      : paymentRouter.holdTokens(item.routeID, item.paymentContract, address(this), totalCost); // Holds tokens for pull collection

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
   */
  function restockItem(uint256 _itemID, uint256 _amount) external onlyOwner(_itemID) {
    /* ========== CHECKS ========== */
    require(marketItems.length < _itemID, "MarketItem does not exist");
    MarketItem memory item = marketItems[_itemID - 1];

    /* ========== EFFECTS ========== */
    marketItems[_itemID - 1].amount += _amount;
    emit ItemRestocked(_itemID, _amount);

    /* ========== INTERACTIONS ========== */
    IERC1155(item.tokenContract).safeTransferFrom(item.owner, address(this), item.tokenID, _amount, "");

    assert(IERC1155(item.tokenContract).balanceOf(address(this), item.tokenID) == item.amount);
  }

  /**
   * @dev Removes _amount of item tokens for _itemID and transfers back to seller's wallet
   *
   * @param _itemID MarketItem's ID
   * @param _amount Amount of tokens being pulled from Marketplace, 0 == pull all tokens
   */
  function pullStock(uint256 _itemID, uint256 _amount) external onlyOwner(_itemID) {
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

    emit stockPulled(_itemID, _amount);

    // Assert internal balances updated correctly, item.amount was initial amount
    assert(marketItems[_itemID - 1].amount < item.amount);
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
  ) external onlyOwner(_itemID) returns (bool) {
    MarketItem memory oldItem = marketItems[_itemID - 1];
    if (!oldItem.routeMutable || _routeID == 0) {
      // If the payment route is not mutable...
      _routeID = oldItem.routeID; // ...then set the input equal to the old routeID
    }
    // If itemLimit == 0, then there is no itemLimit, use type(uint256).max to make itemLimit infinite
    if (_itemLimit == 0) {
      _itemLimit = type(uint256).max;
    }

    marketItems[_itemID - 1] = MarketItem(
      _itemID,
      oldItem.tokenContract,
      oldItem.tokenID,
      oldItem.amount,
      oldItem.owner,
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
   * Use this function to activate/deactivate items for sale on market. Only items that are
   * forSale will be returned by getInStockItems().
   *
   * @param _itemID Marketplace ID of item for sale
   */
  function toggleForSale(uint256 _itemID) external onlyOwner(_itemID) {
    if (marketItems[_itemID - 1].forSale) {
      itemsSoldOut.increment();
      marketItems[_itemID - 1].forSale = false;
    } else {
      itemsSoldOut.decrement();
      marketItems[_itemID - 1].forSale = true;
    }

    // Event added
    emit forSaleToggled(_itemID, marketItems[_itemID - 1].forSale);
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
    uint[] memory itemIDs = new uint256[](unsoldItemCount);

    uint256 i; // itemID counter for ALL MarketItems
    uint256 j = 0; // itemIDs[] index counter for forSale market items

    for (i = 0; j < unsoldItemCount || i < itemCount; i++) {
      if (marketItems[i].forSale) {
        itemIDs[j] = i + 1; // Assign unsoldItem to items[j]
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
  function ownsTokens(address _owner, uint256[] memory _itemIDs) public view returns (bool[] memory hasToken) {
    hasToken = new bool[](_itemIDs.length);
    for (uint i = 0; i < _itemIDs.length; i++){
      MarketItem memory item = marketItems[_itemIDs[i] - 1];
      if (IERC1155(item.tokenContract).balanceOf(_owner, item.tokenID) != 0) {
        hasToken[i] = true;
      }
      else hasToken[i] = false;
    }
  }

  /**
   * @notice This is in case someone mistakenly sends their ERC1155 NFT to this contract address
   */
  function recoverNFT(address _nftContract, uint256 _tokenID, uint256 _amount) external returns (bool) {
    require(IERC1155(_nftContract).balanceOf(address(this), _tokenID) != 0, "NFT not here!");
    uint256 itemID = tokenMap[_nftContract][_tokenID];

    // If tokenID exists as an itemID on pazari, then...
    if(IERC1155(_nftContract).balanceOf(address(this), _tokenID) > marketItems[itemID - 1].amount){
      // Compare MarketItem.amount to balanceOf, set _amount equal to imbalanced stock
      _amount = IERC1155(_nftContract).balanceOf(address(this), _tokenID) - marketItems[itemID - 1].amount;
    }

    IERC1155(_nftContract).safeTransferFrom(address(this), _msgSender(), _tokenID, _amount, "");
    return true;
  }  

}