/**
 * MarketplaceGetters - Version 0.1.1
 *
 * This is a contract full of getter functions for the Marketplace, and is the contract that is
 * deployed. Deploying this contract will deploy Marketplace and PaymentRouter, and all functions
 * are accessed through MarketplaceGetters. More getter functions can be added as necessary. I've
 * included a variety of potentially useful getter functions, though they haven't been fully
 * tested yet for bugs.
 *
 * changed Renamed fetchMarketItems() to getInStockItems(), which is more descriptive of its
 * function as a getter of every market item that is in stock.
 *
 * Patch Notes: V0.1.1
 * Accommodated for custodial design choice
 * - changed Function names for getInStockItems() and getInStockItemIDs() have been changed
 *   to getItemsForSale() and getItemIDsForSale() to reflect change from inStock to forSale.
 * - changed getItemStock now refers to a MarketItem's amount property instead of calling
 *   the ERC1155 contract for a balanceOf() operation
 * - note I kept all of the getter functions in case they are useful for front-end
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Marketplace.sol";

contract MarketplaceGetters is Marketplace {
    using Counters for Counters.Counter;

    constructor(
        address _treasuryAddress,
        address[] memory _developers,
        uint16 _minTax,
        uint16 _maxTax
    ) Marketplace(_treasuryAddress, _developers, _minTax, _maxTax) {
        super;
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
    function getSellersItemIDs(address _seller) public view returns (uint256[] memory itemIDs) {
        itemIDs = sellersMarketItems[_seller];
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
