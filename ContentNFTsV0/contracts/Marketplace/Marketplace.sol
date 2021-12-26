/**
 * Marketplace Version 0.2.2
 *
 * Developer notes - IMPLEMENTED IN VERSION 0.2.0:
 *
 * Introducing tokens and stablecoins, replacing AVAX as a payment method:
 * - MarketItem struct now has paymentContract address for token accepted by seller.
 * - createMarketItem() now takes a payment token contract address as a parameter.
 * - buyMarketItem() now only uses ERC20-compatible tokens for payment, like stablecoins.
 *
 * Marketplace now inherits from PaymentRouter, and has fully implemented the PaymentRouter contract.
 * - MarketItem structs now have the isPush bool, which determines whether PaymentRouter uses
 *   _pushTokens or _holdTokens when a MarketItem is purchased.
 *
 * Marketplace no longer tracks inventory internally, instead all inventory is based on
 * the seller's wallet balance for each token.
 * - Added the inStock bool to the MarketItem struct.
 * -- Used by getInStockItems() to find items for sale, instead of internal inventory count.
 * -- More efficient than checking balanceOf() for every item on the market.
 * -- The inStock bool turns false when the seller runs out of inventory.
 * -- The inStock bool must be toggled back on after more tokens have been minted.
 * - Sellers never lose custody of items sold on Pazari, everything is done through private wallets
 *   which will make selling crypto-native items (like NFTs) easier and more fluid in the future.
 * - idea Instead of using a bool, use uint8 to toggle between a 1 or 2 value, which is cheaper
 *   than toggling a bool. This is due to the way the EVM stores and updates memory, bools are
 *   more expensive to update than uint8. It isn't as intuitive as using bool, but it is cheaper.
 *
 * Sellers can now choose how many of an item a buyer is allowed to purchase/own.
 * - Added itemLimit uint to MarketItem struct.
 * - Added require check for buyMarketItem().
 * - This is to prevent buyers from purchasing more than one rare item, if the seller does not
 *   wish for the buyer to own more than one. Some items may make sense to own more than one,
 *   but most items will likely have a one-item-per-buyer limit. This is set during item creation
 *   and can be modified later.
 *
 * We can now access a list of each seller's items for sale through the sellersMarketItems
 * mapping. This gives us the ability to create seller profiles where all the seller's items
 * can be easily retrieved and displayed. The function for returning this array is
 * getSellersItemIDs().
 *
 * All getter functions have been split off into the MarketplaceGetters contract, which inherits
 * from Marketplace. Marketplace has to be marked abstract, but it still works fine. I made this
 * split because Marketplace was getting too big and was exceeding gas limits during migration.
 * - The constructor() had to be moved to MarketplaceGetters, which rendered Marketplace abstract.
 *
 * Added routeMutable bool to MarketItem struct. This bool determines whether the seller can change
 * the routeID of a MarketItem after creation.
 * - While this can be enforced via the front-end, as long as someone with access to Truffle Console
 *   or a similar tool can call the smart contract they can change the routeID. This was included to
 *   prevent bad actors from scamming collaborators by changing the routeID after creating the item.
 * - This bool should remain as true for MVP, then when we roll out support for collaborations
 *   we will provide the option to choose this bool's value at the time of MarketItem creation.
 *   I'm only including it because it could be useful for many applications to have the ability to
 *   add or subtract recipients from an item's payment route, like for a podcast team whose members
 *   are paid via commissions made from Pazari subscription sales and who occasionally need to hire
 *   new members and remove old ones.
 *
 * Added new events to listen for:
 * - MarketItemSold - Sellers listen for this event.
 * - itemPriceChanged - Buyers listen for this event when items they are watching go down in price.
 * - ItemRestocked - Buyers listen for this event when an item they are watching is back in stock.
 * - itemSoldOut - Sellers listen for this event when an item they are selling is sold out.
 * - MarketItemChanged - Buyers/Sellers listen for this event.
 *
 *
 * 0.2.1 Patch Notes:
 * - Fixed a bug in getInStockItems() (formerly fetchMarketItems()), see MarketplaceGetters.
 * - Fixed a bug in createMarketItem(), see below.
 * - Corrected a lot of inconsistencies in terminology and input argument names.
 * - changed Throughout contract tokenID and itemID were being mixed up. TokenID is the token ID for
 *   the item's ERC1155 contract, while itemID is the ID for the item on the Marketplace contract. This
 *   has now been corrected, and all uses of tokenID and itemID are now correct.
 * - changed Altered comments to more consistently use terms "item" and "token" appropriately, where
 *   "item" refers to the marketplace item, and where "token" refers to the ERC1155 contract token
 *   connected to the market item.
 * - changed createMarketItem() to return the itemID of the new market item instead of a success bool
 * - changed All instances of msg.sender are now _msgSender(), which is required for meta-transactions
 * - changed _itemIDs and _itemsSoldOut have been changed to itemIDs and itemsSoldOut. This is for
 *   consistency. I prefer to use underscores for function inputs and internal functions only, and I
 *   never name a state variable, struct, or mapping with an underscore--with some exceptions for
 *   internal and private visibility.
 *
 * 0.2.2 Patch Notes:
 * Made Marketplace custodial. See function comments for details on what was changed for this.
 * - changed Added two new functions, restockItem() and pullStock(), see below
 * - changed Added "amount" to the ItemRestocked event and MarketItemCreated event
 * - changed Added "amount" to MarketItem struct
 * - changed Made all necessary changes to createMarketItem(), buyMarketItem(), and toggleInStock()
 * - (now toggleForSale()), see below
 *
 *
 * TO IMPLEMENT IN VERSION 0.3.0:
 * - Implement AVAX payments that are PaymentRouter compatible
 * - Implement "item bundles" that allow for chaining multiple tokens together into one itemID, which
 *   can all be purchased in a single transaction
 * - Implement accepted payment token lists, so sellers can choose which tokens they accept instead
 *   of accepting all tokens. This can also be done through the front-end too, which may be the better
 *   way of implementing this feature to save on gas costs.
 * - Optimize the MarketItem struct for storage efficiency. The order in which data types are listed
 *   determines the amount of storage space each instance of the struct takes up. We generally want to
 *   combine all data types that are less than 32 bytes, like bool or uint8, and keep larger data types
 *   near the beginning, like address or uint256. If we *really* have time to optimize, then we can also
 *   use bitwise operators to make the storage even tighter, but the amount of gas saved every time a
 *   new MarketItem is created may not be all that much.
 *
 * TO IMPLEMENT IN VERSION 0.4.0:
 * - Meta-transactions!!
 *
 * TO CONSIDER IMPLEMENTING:
 * - Inventory contracts, which hold the inventory for sellers who choose to use them so they don't have
 *   to use their private wallet or create a new wallet. This would also enable sellers to control the
 *   inventory that is visible to buyers while also reserving some inventory to be given away. This is a
 *   nice-to-have feature that isn't necessary, but it might be useful for many sellers, especially for
 *   collaborations which may need a neutral smart contract to hold all the tokens on behalf of all
 *   parties who worked on the collaboration.
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Dependencies/Counters.sol";
import "../Dependencies/IERC20Metadata.sol";
import "../Dependencies/IERC1155.sol";
import "../PaymentRouter/PaymentRouter.sol";

contract Marketplace is PaymentRouter {
    using Counters for Counters.Counter;
    // These counters are used by getInStockItems()
    Counters.Counter internal itemIDs; // Counter for MarketItem IDs
    Counters.Counter internal itemsSoldOut; // Counter for items with inStock == false

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
         uint itemID;
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
    mapping(address => mapping(uint256 => uint256)) private tokenMap;

    // Fires when item is put on market;
    event MarketItemCreated (
        uint indexed itemID,
        address indexed nftContract,
        uint256 indexed tokenID,
        address seller,
        uint256 price,
        uint256 amount,
        string tokenTicker
    );

    // Fires when item is sold;
    event MarketItemSold (
        uint indexed itemID,
        uint amount,
        address owner
    );

    // Fires when seller changes an item's price
    event itemPriceChanged(
        uint indexed itemID,
        string tokenTicker,
        uint oldPrice,
        uint newPrice
    );

    // Fires when creator restocks items that are sold out
    event ItemRestocked(
        uint indexed itemID,
        uint amount
    );

    // Fires when last item is bought, or when creator removes all items
    event ItemSoldOut(
        uint indexed itemID
    );

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
       address _treasuryAddress, address[] memory _developers, uint16 _minTax, uint16 _maxTax
    ) PaymentRouter(_treasuryAddress, _developers, _minTax, _maxTax){

    }

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
        ) external
        returns (uint256 itemID) {
        // CHECKS
            require(tokenMap[_tokenContract][_tokenID] == 0, "Item already exists");
            require(_price > 0, "Price cannot be 0");
            require(IERC1155(_tokenContract).balanceOf(_msgSender(), _tokenID) > 0, "Insufficient tokens");
            require(IERC1155(_tokenContract).isApprovedForAll(_msgSender(), address(this)), "Insufficient allowance");
            require(_paymentContract != address(0), "Invalid payment token contract address");
            require(paymentRouteID[_routeID].isActive, "Payment route inactive");

            // If itemLimit == 0, then there is no itemLimit, use underflow to make itemLimit infinite
             // Yes, the underflow "error" is intentional
            if(_itemLimit == 0) {
                unchecked {
                    _itemLimit -= 1;
                }
            }

        //EFFECTS
            // Increases itemIDs by 1, stores current value as itemID
            itemIDs.increment(); // Increment itemIDs first so itemIDs begin at 1 instead of 0
            itemID = itemIDs.current();

            // Assigns MarketItem to itemID
            idToMarketItem[itemID] =  MarketItem(
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
    function buyMarketItem(uint256 _itemID, uint256 _amount) external nonReentrant() returns (bool) {
        // Pull data from itemID's MarketItem struct
        MarketItem memory item = idToMarketItem[_itemID];
        // Defines total cost of purchase
        uint256 totalCost = item.price * _amount;

        // CHECKS:
        require(_itemID != 0, "Item does not exist");
        require(item.forSale, "Item not for sale");
        require(item.amount != 0, "Item sold out");
        require(IERC20(item.paymentContract).balanceOf(_msgSender()) >= item.price * _amount, "Insufficient funds");
        require(_msgSender() != item.seller, "Can't buy your own item");
        require(IERC1155(item.tokenContract).balanceOf(_msgSender(), item.tokenID) + _amount <= item.itemLimit,
            "Purchase exceeds item limit");

        // EFFECTS
        if(item.amount <= _amount){ // If buy order exceeds all available stock, then:
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
        item.isPush ?
            _pushTokens(item.routeID, item.paymentContract, totalCost): // Pushes tokens to recipients
            _holdTokens(item.routeID, item.paymentContract, totalCost); // Holds tokens for pull collection

        // Call market item's token contract and transfer token from Marketplace to buyer
        IERC1155(item.tokenContract).safeTransferFrom(address(this), _msgSender(), item.tokenID, _amount, "");

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
        require(IERC1155(item.tokenContract).balanceOf(_msgSender(), item.tokenID) >= _amount,
                "Insufficient tokens to restock");
        require(IERC1155(item.tokenContract).isApprovedForAll(_msgSender(), address(this)),
                "Marketplace is not approved for token transfer");

        // EFFECTS
        idToMarketItem[_itemID].amount += _amount;
        emit ItemRestocked(_itemID, _amount);

        // INTERACTIONS
        IERC1155(item.tokenContract).safeTransferFrom(item.seller, address(this), item.tokenID, _amount, "");

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
        require(item.amount >= _amount,
                "Not enough inventory to pull");

        // Pulls all remaining tokens if _amount == 0
        if(_amount == 0) {
            _amount = item.amount;
        }

        // EFFECTS
        idToMarketItem[_itemID].amount -= _amount;

        // INTERACTIONS
        IERC1155(item.tokenContract).safeTransferFrom(address(this), _msgSender(), item.tokenID, _amount, "");

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
            uint256 _itemLimit)
        external
        onlySeller(_itemID)
        returns (bool){
        MarketItem memory oldItem = idToMarketItem[_itemID];
        if(!oldItem.routeMutable){ // If the payment route is not mutable...
            _routeID = oldItem.routeID; // ...then set the input equal to the old routeID
        }

        idToMarketItem[_itemID] =  MarketItem(
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
        if(idToMarketItem[_itemID].forSale) {
            itemsSoldOut.increment();
            idToMarketItem[_itemID].forSale = false;
        }
        else {
            itemsSoldOut.decrement();
            idToMarketItem[_itemID].forSale = true;
        }
    }

}
