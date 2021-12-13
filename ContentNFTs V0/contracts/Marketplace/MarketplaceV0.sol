// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Dependencies/Counters.sol";
import "../Dependencies/IERC1155.sol";
import "../Dependencies/IERC721.sol";
import "../Dependencies/IERC20.sol";
import "../Dependencies/ReentrancyGuard.sol";

contract MarketplaceV0 is ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIDs; // Counter for MarketItem ID numbers
    Counters.Counter private _itemsSoldOut; // Counter for items that are sold out
     
     // Struct for market items being sold;
     struct MarketItem {
         uint itemID;
         address nftContract;
         uint256 tokenID;
         address payable seller;
         address payable owner;
         uint256 price;
         uint256 amount;
     }
     
     // Mapping that maps item IDs to their MarketItem structs: itemID => MarketItem
     mapping(uint256 => MarketItem) private idToMarketItem;

    // Fires when token is put on market;     
     event MarketItemCreated (
        uint indexed itemID,
        address indexed nftContract,
        uint256 indexed tokenID,
        address seller,
        address owner,
        uint256 price,
        uint256 amount
     );
     
     // Fires when token is sold;
     event MarketItemSold (
         uint indexed itemID,
         uint amount,
         address owner
         );
     
    
    /**
     * @dev Creates a MarketItem struct and assigns it an itemID (V0)
     * 
     * @param nftContract Contract address of the item being sold
     * @param tokenID The token ID of the item being sold
     * @param price The price--in AVAX--of the item being sold
     * @param amount The amount of tokens being sold, if applicable, otherwise amount == 1.
     *
     * note Front-end must call IERC1155.setApprovalForAll(marketAddress, true) before calling
     * this function. The user has to give permission for the marketplace to handle their
     * tokens before this function will pass. I will modify the token contract to auto-approve
     * the market's address so this will not be necessary once implemented.
     *
     * note When payment splitter is implemented this function will need to be reworked so that
     * instead of the seller's address it will be passed an ID or a hash telling the payment
     * splitter which path to take when it receives the value. The front-end will grab this
     * parameter from a mapping in the marketplace contract. For MVP, the payment splitter will
     * split payments three ways: One for the seller, one for the creator, and one for the treasury.
     * In next version we can offer a payment splitter clone for creators that will allow them to
     * further split their payment among any other creators who contributed to their content.
     */
    
    function createMarketItem(
        address nftContract,
        uint256 tokenID,
        uint256 price,
        uint256 amount
        ) public payable {
            require(price > 0, "Price must be greater than 0");

            // Increases _itemIDs by 1, stores current value as itemID
            _itemIDs.increment();
            uint256 itemID = _itemIDs.current();

            // Assigns MarketItem to itemID
            idToMarketItem[itemID] =  MarketItem(
                itemID,
                nftContract,
                tokenID,
                payable(msg.sender),
                payable(address(0)),
                price,
                amount
            );

            // Emits MarketItemCreated event
            emit MarketItemCreated(
                itemID,
                nftContract,
                tokenID,
                msg.sender,
                address(0),
                amount,
                price
            );
        }

    //CREATE FUNCTION FOR REMOVING ITEM FOR SALE

    /**
     * NOTE: Design a token swapper contract that automatically
     * calls Pangolin / Trader Joe DEX and converts buyer's
     * tokens into AVAX before submitting this transaction.
     * This auto-swap feature should be optional, since it will
     * carry much heavier gas fees that could cost around $1.00.
     * 
     * Same token-swapper should be able to work in reverse,
     * where it takes AVAX as input and outputs any arbitrary
     * token. This will work in conjunction with our payment
     * splitter to provide better UX.
     */

    /**
     * @dev Purchases market item itemID
     * 
     * @param _itemID ID of item being bought
     * @param _amount Amount of item itemID being purchased
     */
    function buyMarketItem(uint256 _itemID, uint256 _amount) external payable nonReentrant {

            // Pull data from itemID's MarketItem struct
            address nftContract = idToMarketItem[_itemID].nftContract;
            uint price = idToMarketItem[_itemID].price;
            uint tokenID = idToMarketItem[_itemID].itemID;
            address payable seller = idToMarketItem[_itemID].seller;
            uint amount = idToMarketItem[_itemID].amount;

            // CHECKS:
            require(amount != 0, "Item sold out");
            require(_amount <= amount, "Insufficient tokens for sale");
            require(msg.value == price * _amount, "Insufficient funds");

            // EFFECTS
            emit MarketItemSold(tokenID, _amount, msg.sender);
            idToMarketItem[_itemID].owner = payable(msg.sender);
            _itemsSoldOut.increment();
            if(_amount <= amount){
                idToMarketItem[_itemID].amount -= _amount;
            }

            //INTERACTIONS
            // Transfer AVAX from buyer to seller
            /* 
             * note: When payment splitter is implemented, I will replace this
             * operation with a function call to payment splitter with value attached.
             */
            (bool success, ) = seller.call{value: price}("");
            require(success, "Transfer failed.");
            
            // Call token contract and transfer token from seller to buyer
            IERC1155(nftContract).safeTransferFrom(seller, msg.sender, tokenID, _amount, "");
        }        

    /**
     * @dev Returns an array of all items for sale on marketplace
     *
     * note This is from the clone OpenSea tutorial, but I modified it to be
     * slimmer, lighter, and easier to understand.
     */
    function fetchMarketItems() public view returns (MarketItem[] memory) {
        // Fetch total item count, both sold and unsold
        uint itemCount = _itemIDs.current();
        // Calculate total unsold items
        uint unsoldItemCount = _itemIDs.current() - _itemsSoldOut.current();

        // Create empty array of all unsold MarketItem structs with length unsoldItemCount
        MarketItem[] memory items = new MarketItem[](unsoldItemCount);

        // Loop that populates the items[] array 
        // note We begin counting at 1 because item IDs start at 1
        for (uint i = 1; i <= itemCount; i++) {
            if (idToMarketItem[i].amount > 0) { // All unsold items have amount > 0
                MarketItem memory unsoldItem = idToMarketItem[i]; // Store MarketItem as unsoldItem
                items[i - 1] = unsoldItem; // Assign unsoldItem to position i - 1 in items[] array
            }
        }
        // Return populated array of all unsold items
        return items;
    }
      
}



