// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Dependencies/Counters.sol";
import "../Dependencies/IERC20Metadata.sol";
import "../Dependencies/ERC1155Holder.sol";
import "../Dependencies/IERC1155.sol";
import {PaymentRouter} from "../PaymentRouter/PaymentRouter.sol";

contract Marketplace is PaymentRouter, ERC1155Holder {
  using Counters for Counters.Counter;
  // These counters are used by getInStockItems()
  Counters.Counter private itemIDs; // Counter for MarketItem IDs
  Counters.Counter private itemsSoldOut; // Counter for items with inStock == false

  // Struct for market items being sold;
  /**
   * changed:
   * - nftContract => tokenContract
   * - tokenContract => paymentContract
   *
   * added:
   * - isPush
   * - routeID
   * - routeMutable
   * - inStock
   * - itemLimit
   */
  struct MarketItem {
    uint256 itemID;
    address tokenContract;
    uint256 tokenID;
    uint256 amount;
    address seller;
    uint256 price;
    address paymentContract;
    bool isPush;
    bytes32 routeID;
    bool routeMutable;
    bool forSale;
    uint256 itemLimit;
  }

  // Mapping that maps item IDs to their MarketItem structs
  // itemID => MarketItem
  mapping(uint256 => MarketItem) public idToMarketItem;

  // Maps a seller's address to an array of all itemIDs they have created
  // seller's address => itemID
  mapping(address => uint256[]) public sellersMarketItems;

  // Maps a tokenContract address to a mapping of tokenIds => itemIds
  // The purpose of this is to prevent duplicate items for same token
  // tokenContract address => tokenID => itemID
  mapping(address => mapping(uint256 => uint256)) public tokenMap;

  // Fires when item is put on market;
  event MarketItemCreated(
    uint256 indexed itemID,
    address indexed nftContract,
    uint256 indexed tokenID,
    address seller,
    uint256 price,
    uint256 amount,
    string tokenTicker
  );

  // Fires when item is sold;
  event MarketItemSold(uint256 indexed itemID, uint256 amount, address owner);

  // Fires when seller changes an item's price
  event ItemPriceChanged(
    uint256 indexed itemID,
    string tokenTicker,
    uint256 oldPrice,
    uint256 newPrice
  );

  // Fires when creator restocks items that are sold out
  event ItemRestocked(uint256 indexed itemID, uint256 amount);

  // Fires when last item is bought, or when creator removes all items
  event ItemSoldOut(uint256 indexed itemID);

  // Fires when market item details are modified
  /**
   * changed tokenContract => paymentContract
   */
  event MarketItemChanged(
    uint256 itemID,
    uint256 price,
    address paymentContract,
    bool isPush,
    bytes32 routeID,
    uint256 itemLimit
  );

  // Restricts access to the seller of the item
  modifier onlySeller(uint256 _itemID) {
    require(idToMarketItem[_itemID].seller == _msgSender(), "Unauthorized: Only seller");
    _;
  }

  constructor(
    address _treasuryAddress,
    address[] memory _developers,
    uint16 _minTax,
    uint16 _maxTax
  ) PaymentRouter(_treasuryAddress, _developers, _minTax, _maxTax) {}

  /**
   * @dev Creates a MarketItem struct and assigns it an itemID
   *
   * @param _tokenContract Token contract address of the item being sold
   * @param _sellerAddress Address where tokens are being sold from
   * @param _tokenID The token contract ID of the item being sold
   * @param _amount The amount of items available for purchase
   * @param _price The price--in payment tokens--of the item being sold
   * @param _paymentContract Contract address of token accepted for payment--usually stablecoins
   * @param _isPush Tells PaymentRouter to use push or pull function for this item
   * @param _forSale Sets whether item is immediately up for sale
   * @param _routeID The routeID of the payment route assigned to this item
   * @param _itemLimit How many items a buyer can own, 0 == no limit
   * @param _routeMutable Assigns mutability to the routeID, keep false for most items
   *
   * note Front-end must call IERC1155.setApprovalForAll(marketAddress, true) before calling
   * this function. The seller has to give permission for the marketplace to handle their
   * tokens before this function will pass. I will modify the token contract to auto-approve
   * the market's address so this will not be necessary once implemented.
   *
   * changed For consistency in how input arguments are named:
   * - _tokenContract => _paymentContract
   * - nftContract => _tokenContract
   * - tokenID => _tokenID
   * - price => _price
   * - amount => _amount
   *
   * changed Return data is now the itemID of the market item instead of a success bool
   *
   * changed Added _routeMutable as an input. This argument determines whether the seller
   * can alter the routeID of the MarketItem, which will change the commissions and recipients
   * of the payment route. Mutability may be useful in certain arrangements, but for things
   * like collaborations immutability is the best option so all participants of the collaboration
   * can know they will always get paid and nobody can change it.
   *
   * changed Added _sellerAddress as an input. This argument assigns an address to be the "seller"
   * who has permission to modify the MarketItem and toggle forSale.
   *
   * Patch Notes V 0.2.2
   * Accommodated for custodial design of Marketplace
   * - Changed _itemLimit now accepts 0 as a valid input, where 0 is used for infinite itemLimit.
   *   It achieves this by intentional underflowing.
   * - Changed Added require check for ERC1155.isApprovedForAll()
   * - Changed Added an invariant check to make sure the ERC1155 balanceOf reports the same
   *   number as the MarketItem's amount for the Marketplace's balance
   * - Changed Added transferFrom() operation for tokens
   * - Added a few new comments to better organize the function
   */

  function createMarketItem(
    address _tokenContract,
    address _sellerAddress,
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
    // CHECKS
    require(tokenMap[_tokenContract][_tokenID] == 0, "Item already exists");
    require(_price > 0, "Price cannot be 0");
    require(IERC1155(_tokenContract).balanceOf(_msgSender(), _tokenID) > 0, "Insufficient tokens");
    require(
      IERC1155(_tokenContract).isApprovedForAll(_msgSender(), address(this)),
      "Insufficient allowance"
    );
    require(_paymentContract != address(0), "Invalid payment token contract address");
    require(paymentRouteID[_routeID].isActive, "Payment route inactive");

    // If itemLimit == 0, then there is no itemLimit, use underflow to make itemLimit infinite
    // Yes, the underflow "error" is intentional
    if (_itemLimit == 0) {
      unchecked {
        _itemLimit -= 1;
      }
    }

    //EFFECTS
    // Increases itemIDs by 1, stores current value as itemID
    itemIDs.increment(); // Increment itemIDs first so itemIDs begin at 1 instead of 0
    itemID = itemIDs.current();

    // Assigns MarketItem to itemID
    idToMarketItem[itemID] = MarketItem(
      itemID,
      _tokenContract,
      _tokenID,
      _amount,
      _sellerAddress,
      _price,
      _paymentContract,
      _isPush,
      _routeID,
      _routeMutable,
      _forSale,
      _itemLimit
    );

    // Store new MarketItem in local variable
    MarketItem memory item = idToMarketItem[itemID];

    // Push itemID to seller's market items array
    sellersMarketItems[_msgSender()].push(itemID);

    // Assign itemID to tokenMap mapping
    tokenMap[_tokenContract][_tokenID] = itemID;

    // Emits MarketItemCreated event
    emit MarketItemCreated(
      itemID,
      _tokenContract,
      _tokenID,
      _msgSender(),
      _price,
      _amount,
      IERC20Metadata(_paymentContract).symbol()
    );

    // INTERACTIONS
    // Transfer tokens from seller to Marketplace
    IERC1155(_tokenContract).safeTransferFrom(_msgSender(), address(this), _tokenID, _amount, "");

    // This should pass in all conditions
    assert(IERC1155(item.tokenContract).balanceOf(address(this), item.tokenID) == item.amount);
  }

  /**
   * @dev Purchases market item itemID
   *
   * @param _itemID Market ID of item being bought
   * @param _amount Amount of item itemID being purchased
   *
   * Patch Notes: V0.2.1
   * bug tokenID referred to item.itemID, but was supposed to be item.tokenID
   * bug In balanceOf require check, boolean operator was ==, which will revert if user's balance
   * is greater than price * _amount
   *
   * changed For consistency:
   * - nftContract => tokenContract
   * - tokenContract => paymentContract
   *
   * changed Removed almost all local variable declarations because stack was running too deep
   *
   * Patch Notes: V0.2.2
   * - Removed sellersBalance and its require check, replaced with check for inventory != 0
   * - Replaced sellersBalance with item.amount
   * - Replaced idToMarketItem[_itemID].inStock with idToMarketItem[_itemID].forSale
   * - Added _amount to last require check, so the buyer's _amount plus their balanceOf cannot
   *   be greater than the itemLimit
   * - Events were emitting the tokenID instead of itemID, fixed it so now the events will report
   *   the itemID that was sold instead of the tokenID
   * - _pushTokens and _holdTokens were receiving the item's price, not the correct amount of
   *   tokens that are the price * amount. Added the totalCost uint to calculate this, and
   *   replaced item.price with totalCost for these functions.
   * - Added a few extra comments
   * - Added fringe check for _itemID == 0
   */
  function buyMarketItem(uint256 _itemID, uint256 _amount) external returns (bool) {
    // Pull data from itemID's MarketItem struct
    MarketItem memory item = idToMarketItem[_itemID];
    // Defines total cost of purchase
    uint256 totalCost = item.price * _amount;

    // CHECKS:
    require(_itemID != 0, "Item does not exist");
    require(item.forSale, "Item not for sale");
    require(item.amount != 0, "Item sold out");
    require(
      IERC20(item.paymentContract).balanceOf(_msgSender()) >= item.price * _amount,
      "Insufficient funds"
    );
    require(_msgSender() != item.seller, "Can't buy your own item");
    require(
      IERC1155(item.tokenContract).balanceOf(_msgSender(), item.tokenID) + _amount <=
        item.itemLimit,
      "Purchase exceeds item limit"
    );

    // EFFECTS
    if (item.amount <= _amount) {
      // If buy order exceeds all available stock, then:
      itemsSoldOut.increment(); // Increment counter variable for items sold out
      _amount = item.amount; // Set _amount to the item's remaining inventory
      idToMarketItem[_itemID].forSale = false; // Set forSale to false
      emit ItemSoldOut(item.itemID); // Emit itemSoldOut event
    }

    // Adjust Marketplace's itemID inventory
    idToMarketItem[_itemID].amount -= _amount;
    // Emit marketItemSold
    emit MarketItemSold(item.itemID, _amount, _msgSender());

    //INTERACTIONS
    // Send ERC20 tokens through PaymentRouter, isPush determines which function is used
    // note PaymentRouter functions make external calls to ERC20 contracts, thus they are interactions
    item.isPush
      ? _pushTokens(item.routeID, item.paymentContract, totalCost) // Pushes tokens to recipients
      : _holdTokens(item.routeID, item.paymentContract, totalCost); // Holds tokens for pull collection

    // Call market item's token contract and transfer token from Marketplace to buyer
    IERC1155(item.tokenContract).safeTransferFrom(
      address(this),
      _msgSender(),
      item.tokenID,
      _amount,
      ""
    );

    assert(IERC1155(item.tokenContract).balanceOf(address(this), item.tokenID) == item.amount);
    return true;
  }

  /**
   * @dev Transfers more stock to a MarketItem, requires minting more tokens first and setting
   * approval for Marketplace
   *
   * @param _itemID MarketItem ID
   * @param _amount Amount of tokens being restocked
   */
  function restockItem(uint256 _itemID, uint256 _amount) external onlySeller(_itemID) {
    MarketItem memory item = idToMarketItem[_itemID];
    // CHECKS
    require(_itemID != 0, "MarketItem does not exist");
    require(
      IERC1155(item.tokenContract).balanceOf(_msgSender(), item.tokenID) >= _amount,
      "Insufficient tokens to restock"
    );
    require(
      IERC1155(item.tokenContract).isApprovedForAll(_msgSender(), address(this)),
      "Marketplace is not approved for token transfer"
    );

    // EFFECTS
    idToMarketItem[_itemID].amount += _amount;
    emit ItemRestocked(_itemID, _amount);

    // INTERACTIONS
    IERC1155(item.tokenContract).safeTransferFrom(
      item.seller,
      address(this),
      item.tokenID,
      _amount,
      ""
    );

    assert(IERC1155(item.tokenContract).balanceOf(address(this), item.tokenID) == item.amount);
  }

  /**
   * @dev Removes _amount of item tokens for _itemID and transfers back to seller's wallet
   *
   * @param _itemID MarketItem's ID
   * @param _amount Amount of tokens being pulled from Marketplace, 0 == pull all tokens
   */
  function pullStock(uint256 _itemID, uint256 _amount) external onlySeller(_itemID) {
    MarketItem memory item = idToMarketItem[_itemID]; // Store initial values
    // CHECKS
    require(_itemID != 0, "MarketItem does not exist");
    require(item.amount >= _amount, "Not enough inventory to pull");

    // Pulls all remaining tokens if _amount == 0
    if (_amount == 0) {
      _amount = item.amount;
    }

    // EFFECTS
    idToMarketItem[_itemID].amount -= _amount;

    // INTERACTIONS
    IERC1155(item.tokenContract).safeTransferFrom(
      address(this),
      _msgSender(),
      item.tokenID,
      _amount,
      ""
    );

    // This should always pass
    assert(idToMarketItem[_itemID].amount < item.amount);
  }

  /**
   * @dev Function that allows item creator to change price, accepted payment
   * token, whether token uses push or pull routes, and payment route.
   *
   * @param _itemID Market item ID
   * @param _price Market price--in payment tokens
   * @param _paymentContract Contract address of token accepted for payment
   * @param _isPush Tells PaymentRouter to use push or pull function
   * @param _routeID Payment route ID, only mutable if routeMutable == true
   * @param _itemLimit Buyer's purchase limit for item
   *
   * note What cannot be modified:
   * - Token contract address
   * - Token contract token ID
   * - Seller of market item
   * - RouteID mutability
   * - Item's forSale status
   *
   * changed Added MarketItemChanged event
   *
   * changed Added if() block to handle routeID mutability
   */
  function modifyMarketItem(
    uint256 _itemID,
    uint256 _price,
    address _paymentContract,
    bool _isPush,
    bytes32 _routeID,
    uint256 _itemLimit
  ) external onlySeller(_itemID) returns (bool) {
    MarketItem memory oldItem = idToMarketItem[_itemID];
    if (!oldItem.routeMutable) {
      // If the payment route is not mutable...
      _routeID = oldItem.routeID; // ...then set the input equal to the old routeID
    }

    idToMarketItem[_itemID] = MarketItem(
      _itemID,
      oldItem.tokenContract,
      oldItem.tokenID,
      oldItem.amount,
      oldItem.seller,
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
   *
   * Patch Notes V0.2.2
   * - Replaced idToMarketItem[_itemID].inStock with idToMarketItem[_itemID].forSale
   * - Removed events, since they don't really make sense to use here.
   */
  function toggleForSale(uint256 _itemID) external onlySeller(_itemID) {
    if (idToMarketItem[_itemID].forSale) {
      itemsSoldOut.increment();
      idToMarketItem[_itemID].forSale = false;
    } else {
      itemsSoldOut.decrement();
      idToMarketItem[_itemID].forSale = true;
    }
  }

  /**
   * @dev Helper functions to retrieve the last and next created itemIDs
   *
   * note For front-end: Do not rely on these functions to tell you what the next itemID is going to be,
   * since if multiple users are creating new MarketItems then by the time the browser receives an answer
   * from either of these functions the new MarketItems will have already taken the itemID. Instead, use
   * getSellersItemIDs() and pull the last value in the array if you need to obtain the itemID of a
   * newly created MarketItem.
   */
  function getLastItemID() public view returns (uint256 itemID) {
    itemID = itemIDs.current();
  }

  function getNextItemID() public view returns (uint256 itemID) {
    itemID = getLastItemID() + 1;
  }

  /**
   * @dev Returns an array of all itemIDs created by _seller
   *
   * Use this for seller profiles where all items created by the seller can be quickly retrieved
   * and displayed on one page. In this case, chain together getSellersItemIDs(), getMarketItem(),
   * and getItemStock() to return this information.
   */
  function getSellersItemIDs(address _seller) public view returns (uint256[] memory) {
    return sellersMarketItems[_seller];
  }

  /**
   * @dev Returns an array of all items for sale on marketplace
   *
   * note This is from the clone OpenSea tutorial, but I modified it to be
   * slimmer, lighter, and easier to understand.
   *
   * bug Added j as a counter variable for unsold items array. I realized that
   * we can't use items[i - 1] since i is being incremented across entire list
   * of market items and will not correspond 1:1 with items[], which only has a
   * length of unsoldItemCount.
   *
   * changed Added j <= unsoldItemCount to loop parameters to terminate the
   * loop once items[] has been fully populated. Otherwise, loop will iterate
   * through entire inventory of market. Hopefully this might improve efficiency.
   *
   * changed Declared i and j outside of for loop, added comments
   *
   * changed Switched idToMarketItem[i].amount to idToMarketItem[i].inStock, so
   * only items that are "in stock" will be shown on list
   *
   * note Because item inventory is no longer tracked internally, I had to implement
   * a new function, getItemStock(), to read sellers' balances, and getAllMarketItems()
   * no longer reports the internal inventory of the market item. This works fine for
   * use on the front-end, where we can combine getAllMarketItems() and getItemStock()
   * to return item details along with its stock. However, in testing this is a little
   * trickier to work with, so having dedicated getter functions for item stock is useful.
   */
  function getItemsForSale() public view returns (MarketItem[] memory) {
    // Fetch total item count, both sold and unsold
    uint256 itemCount = itemIDs.current();
    // Calculate total unsold items
    uint256 unsoldItemCount = itemCount - itemsSoldOut.current();

    // Create empty array of all unsold MarketItem structs with fixed length unsoldItemCount
    MarketItem[] memory items = new MarketItem[](unsoldItemCount);

    uint256 i; // itemID counter for ALL market items, starts at 1
    uint256 j; // items[] index counter for forSale market items, starts at 0

    // Loop that populates the items[] array
    for (i = 1; j < unsoldItemCount || i <= itemCount; i++) {
      if (idToMarketItem[i].forSale) {
        MarketItem memory unsoldItem = idToMarketItem[i];
        items[j] = unsoldItem; // Assign unsoldItem to items[j]
        j++; // Increment j
      }
    }
    // Return arrays of all unsold items and their inventory
    return (items);
  }

  /**
   * @dev Getter function for all itemIDs with forSale. This function should run lighter and faster
   * than getItemsForSale() because it doesn't return structs.
   *
   * Use this function in combination with the following functions if getAllMarketItems() is too
   * awkward or inefficient to use. You would first call getItemIDs() and store the return value,
   * then feed that return value into getMarketItem() and getItemStock(). It also may be useful
   * to return a list of all inStock itemIDs for various other purposes too.
   */
  function getItemIDsForSale() public view returns (uint256[] memory itemIDs_) {
    uint256 itemCount = itemIDs.current();
    uint256 unsoldItemCount = itemCount - itemsSoldOut.current();
    itemIDs_ = new uint256[](unsoldItemCount);

    uint256 i; // itemID counter for ALL market items, starts at 1
    uint256 j; // itemIDs_[] index counter for STOCKED market items, starts at 0

    for (i = 1; j < unsoldItemCount || i <= itemCount; i++) {
      if (idToMarketItem[i].forSale) {
        itemIDs_[j] = i; // Assign unsoldItem to items[j]
        j++; // Increment j
      }
    }
  }

  /**
   * @dev Returns a single MarketItem
   */
  function getMarketItem(uint256 _itemID) public view returns (MarketItem memory marketItem) {
    marketItem = idToMarketItem[_itemID];
  }

  /**
   * @dev Overloaded version of getMarketItem that takes an array as argument and returns an array
   */
  function getMarketItem(uint256[] memory _itemIDs)
    public
    view
    returns (MarketItem[] memory marketItem)
  {
    marketItem = new MarketItem[](_itemIDs.length);
    for (uint256 i = 0; i < _itemIDs.length; i++) {
      marketItem[i] = idToMarketItem[_itemIDs[i]];
    }
  }

  /**
   * @dev Returns the total inventory of a MarketItem
   */
  function getItemStock(uint256 _itemID) public view returns (uint256 itemStock) {
    MarketItem memory item = idToMarketItem[_itemID];
    itemStock = item.amount;
  }

  /**
   * @dev Overloaded version of getItemStock that takes an array of itemIDs and returns an array of
   * item inventories.
   */
  function getItemStock(uint256[] memory _itemIDs)
    public
    view
    returns (uint256[] memory itemStocks)
  {
    itemStocks = new uint256[](_itemIDs.length);
    for (uint256 i = 0; i < _itemIDs.length; i++) {
      itemStocks[i] = getItemStock(_itemIDs[i]);
    }
  }
}
