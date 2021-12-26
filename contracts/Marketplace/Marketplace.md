Marketplace Version 0.2.2

Developer notes - IMPLEMENTED IN VERSION 0.2.0:

Introducing tokens and stablecoins, replacing AVAX as a payment method:
- MarketItem struct now has paymentContract address for token accepted by seller.
- createMarketItem() now takes a payment token contract address as a parameter.
- buyMarketItem() now only uses ERC20-compatible tokens for payment, like stablecoins.

Marketplace now inherits from PaymentRouter, and has fully implemented the PaymentRouter contract.
- MarketItem structs now have the isPush bool, which determines whether PaymentRouter uses
  _pushTokens or _holdTokens when a MarketItem is purchased.

Marketplace no longer tracks inventory internally, instead all inventory is based on
the seller's wallet balance for each token.
- Added the inStock bool to the MarketItem struct.
-- Used by getInStockItems() to find items for sale, instead of internal inventory count.
-- More efficient than checking balanceOf() for every item on the market.
-- The inStock bool turns false when the seller runs out of inventory.
-- The inStock bool must be toggled back on after more tokens have been minted.
- Sellers never lose custody of items sold on Pazari, everything is done through private wallets
  which will make selling crypto-native items (like NFTs) easier and more fluid in the future.
- idea Instead of using a bool, use uint8 to toggle between a 1 or 2 value, which is cheaper
  than toggling a bool. This is due to the way the EVM stores and updates memory, bools are
  more expensive to update than uint8. It isn't as intuitive as using bool, but it is cheaper.

Sellers can now choose how many of an item a buyer is allowed to purchase/own.
- Added itemLimit uint to MarketItem struct.
- Added require check for buyMarketItem().
- This is to prevent buyers from purchasing more than one rare item, if the seller does not
  wish for the buyer to own more than one. Some items may make sense to own more than one,
  but most items will likely have a one-item-per-buyer limit. This is set during item creation
  and can be modified later.

We can now access a list of each seller's items for sale through the sellersMarketItems
mapping. This gives us the ability to create seller profiles where all the seller's items
can be easily retrieved and displayed. The function for returning this array is
getSellersItemIDs().

All getter functions have been split off into the MarketplaceGetters contract, which inherits
from Marketplace. Marketplace has to be marked abstract, but it still works fine. I made this
split because Marketplace was getting too big and was exceeding gas limits during migration.
- The constructor() had to be moved to MarketplaceGetters, which rendered Marketplace abstract.

Added routeMutable bool to MarketItem struct. This bool determines whether the seller can change
the routeID of a MarketItem after creation.
- While this can be enforced via the front-end, as long as someone with access to Truffle Console
  or a similar tool can call the smart contract they can change the routeID. This was included to
  prevent bad actors from scamming collaborators by changing the routeID after creating the item.
- This bool should remain as true for MVP, then when we roll out support for collaborations
  we will provide the option to choose this bool's value at the time of MarketItem creation.
  I'm only including it because it could be useful for many applications to have the ability to
  add or subtract recipients from an item's payment route, like for a podcast team whose members
  are paid via commissions made from Pazari subscription sales and who occasionally need to hire
  new members and remove old ones.

Added new events to listen for:
- MarketItemSold - Sellers listen for this event.
- ItemPriceChanged - Buyers listen for this event when items they are watching go down in price.
- ItemRestocked - Buyers listen for this event when an item they are watching is back in stock.
- itemSoldOut - Sellers listen for this event when an item they are selling is sold out.
- MarketItemChanged - Buyers/Sellers listen for this event.


0.2.1 Patch Notes:
- Fixed a bug in getInStockItems() (formerly fetchMarketItems()), see MarketplaceGetters.
- Fixed a bug in createMarketItem(), see below.
- Corrected a lot of inconsistencies in terminology and input argument names.
- changed Throughout contract tokenID and itemID were being mixed up. TokenID is the token ID for
  the item's ERC1155 contract, while itemID is the ID for the item on the Marketplace contract. This
  has now been corrected, and all uses of tokenID and itemID are now correct.
- changed Altered comments to more consistently use terms "item" and "token" appropriately, where
  "item" refers to the marketplace item, and where "token" refers to the ERC1155 contract token
  connected to the market item.
- changed createMarketItem() to return the itemID of the new market item instead of a success bool
- changed All instances of msg.sender are now _msgSender(), which is required for meta-transactions
- changed _itemIDs and _itemsSoldOut have been changed to itemIDs and itemsSoldOut. This is for
  consistency. I prefer to use underscores for function inputs and internal functions only, and I
  never name a state variable, struct, or mapping with an underscore--with some exceptions for
  internal and private visibility.

0.2.2 Patch Notes:
Made Marketplace custodial. See function comments for details on what was changed for this.
- changed Added two new functions, restockItem() and pullStock(), see below
- changed Added "amount" to the ItemRestocked event and MarketItemCreated event
- changed Added "amount" to MarketItem struct
- changed Made all necessary changes to createMarketItem(), buyMarketItem(), and toggleInStock()
- (now toggleForSale()), see below


TO IMPLEMENT IN VERSION 0.3.0:
- Implement AVAX payments that are PaymentRouter compatible
- Implement "item bundles" that allow for chaining multiple tokens together into one itemID, which
  can all be purchased in a single transaction
- Implement accepted payment token lists, so sellers can choose which tokens they accept instead
  of accepting all tokens. This can also be done through the front-end too, which may be the better
  way of implementing this feature to save on gas costs.
- Optimize the MarketItem struct for storage efficiency. The order in which data types are listed
  determines the amount of storage space each instance of the struct takes up. We generally want to
  combine all data types that are less than 32 bytes, like bool or uint8, and keep larger data types
  near the beginning, like address or uint256. If we really have time to optimize, then we can also
  use bitwise operators to make the storage even tighter, but the amount of gas saved every time a
  new MarketItem is created may not be all that much.

TO IMPLEMENT IN VERSION 0.4.0:
- Meta-transactions!!

TO CONSIDER IMPLEMENTING:
- Inventory contracts, which hold the inventory for sellers who choose to use them so they don't have
  to use their private wallet or create a new wallet. This would also enable sellers to control the
  inventory that is visible to buyers while also reserving some inventory to be given away. This is a
  nice-to-have feature that isn't necessary, but it might be useful for many sellers, especially for
  collaborations which may need a neutral smart contract to hold all the tokens on behalf of all
  parties who worked on the collaboration.
