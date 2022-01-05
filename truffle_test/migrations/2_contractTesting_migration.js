/**
 * This contract does not test the contract factory's upgradable shell nor
 * the contract factory itself. I couldn't figure out how to get it working
 * very fast and I was wasting too much time. We can use this one for now.
 *
 * These tests more or less run through the basic functionality of Pazari:
 * - Tokenizing content (minting PazariTokens)
 * - Listing tokenized content (createMarketItem)
 * - Getting a list of all tokens for sale
 *
 * FEATURES TO TEST:
 * - Burning tokens removes user from tokenHolders array for that tokenID
 * - Airdrop function
 */

const Marketplace = artifacts.require("Marketplace");
const PaymentRouter = artifacts.require("PaymentRouter");
const ERC20 = artifacts.require("ERC20");
const PazariTokenMVP = artifacts.require("PazariTokenMVP");
const FactoryPazariTokenMVP = artifacts.require("FactoryPazariTokenMVP");

module.exports = async function (deployer, network, accounts) {
  let buyer = accounts[0];
  let seller = accounts[1];
  let treasury = accounts[4];

  //DEPLOY PAYMENT ROUTER
  await deployer.deploy(PaymentRouter, treasury, [seller], 300, 10000, { from: seller });
  let router = await PaymentRouter.deployed();

  //DEPLOY MARKETPLACE
  await deployer.deploy(Marketplace, router.address, {
    gas: 4700000,
    gasPrice: 8000000000,
    from: seller,
  });
  let market = await Marketplace.deployed();

  //DEPLOY STABLECOIN
  await deployer.deploy(ERC20, "Magic Internet Money", "MIM", web3.utils.toWei("200"), { from: buyer });
  let stablecoin = await ERC20.deployed();

  //DEPLOY PAZARI TOKEN
  let contractOwners = [seller, router.address, market.address];

  await deployer.deploy(PazariTokenMVP, contractOwners, { from: seller });
  let pazariToken = await PazariTokenMVP.deployed();

  console.log("stablecoin.address = " + (await stablecoin.address));
  console.log("market.address = " + (await market.address));
  console.log("pazariToken.address = " + (await pazariToken.address));
  console.log("router.address = " + (await router.address));

  //Function parameters for router.openPaymentRoute()
  let recipients = [seller, accounts[2], accounts[3]];
  let commissions = [5000, 3150, 1850]; // 50%, 31.5%, 18.5%
  let routeTax = 300;
  console.log("Royalty recipients: " + recipients);
  console.log("Commissions: " + commissions);

  //Function parameters for market.CreateMarketItem():
  let itemID; // Assigned dynamically via getNextItemID()
  let itemID2;
  let itemID3;
  let tokenID = 1; //tokenID and itemID are same
  let tokenID2 = 2;
  let tokenID3 = 3;
  // Price in stablecoins
  let price = web3.utils.toWei("9.99");
  let price2 = web3.utils.toWei("49.99");
  let price3 = web3.utils.toWei("14.99");
  // Amount of stablecoins to approve
  let approveAmount = web3.utils.toWei("200.00");
  // Balance limit for token, 0 == no limit
  let itemLimit1 = 3;
  let itemLimit2 = 1;
  let itemLimit3 = 0;
  // Amount of items to sell, 0 == transfer all tokens minted
  let sellAmount1 = 0;
  let sellAmount2 = 50;
  let sellAmount3 = 0;
  // Amount of items to buy, 0 == purchase itemLimit
  let amountBuy = 0;
  let amountBuy2 = 1;
  let amountBuy3 = 5;
  let paymentContract = stablecoin.address;
  let isPush = true;
  let isPull = false;
  let routeID; // Assigned dynamically
  let routeID2;

  //Function parameters for pazariToken.createNewToken() and pazariToken.mint():
  let amountMint = 10000000000;
  let amountMint2 = 100;
  let amountMint3 = 200000;
  let supplyCap1 = 0;
  let supplyCap2 = 100;
  let supplyCap3 = 500000;
  let isMintable1 = true;
  let isMintable2 = false;
  let isMintable3 = true;
  let tokenURI = "WEBSITE URL";
  let data = 0x0;

  //CHECK INITIAL STABLECOIN BALANCES
  console.log("TESTING: Checking initial stablecoin balances");
  console.log("Buyer: $" + web3.utils.fromWei(await stablecoin.balanceOf(buyer)));
  console.log("Seller: $" + web3.utils.fromWei(await stablecoin.balanceOf(seller)));
  console.log("Recipient 1: $" + web3.utils.fromWei(await stablecoin.balanceOf(accounts[2])));
  console.log("Recipient 2: $" + web3.utils.fromWei(await stablecoin.balanceOf(accounts[3])));
  console.log("Pazari Treasury: $" + web3.utils.fromWei(await stablecoin.balanceOf(accounts[4])));

  //MINT ITEM TOKENS
  console.log("TESTING: PazariTokenMVP.createNewToken()");
  console.log("Creating new item tokens");
  console.log("tokenID 1 is a standard edition token with supply of " + amountMint);
  await pazariToken.createNewToken(tokenURI, amountMint, supplyCap1, isMintable1, { from: seller });
  console.log(tokenID);
  console.log("tokenID 2 is a limited edition item, with supply of " + amountMint2);
  await pazariToken.createNewToken(tokenURI, amountMint2, supplyCap2, isMintable2, { from: seller });
  console.log("tokenID 3 is a standard edition item, with supply of " + amountMint3);
  await pazariToken.createNewToken(tokenURI, amountMint3, supplyCap3, isMintable3, { from: seller });

  //CHECK INITIAL PAZARI TOKEN BALANCES
  console.log("TESTING: Check post-mint PazariToken balances");
  console.log("Checking pazariToken balances for tokenID 1: (buyer: accounts[0], seller: accounts[1])");
  console.log(await pazariToken.balanceOf(accounts[0], tokenID).then((bn) => bn.toNumber()));
  console.log(await pazariToken.balanceOf(accounts[1], tokenID).then((bn) => bn.toNumber()));
  console.log("Checking pazariToken balances for tokenID 2: (buyer: accounts[0], seller: accounts[1])");
  console.log(await pazariToken.balanceOf(accounts[0], tokenID2).then((bn) => bn.toNumber()));
  console.log(await pazariToken.balanceOf(accounts[1], tokenID2).then((bn) => bn.toNumber()));
  console.log("Checking pazariToken balances for tokenID 3: (buyer: accounts[0], seller: accounts[1])");
  console.log(await pazariToken.balanceOf(accounts[0], tokenID3).then((bn) => bn.toNumber()));
  console.log(await pazariToken.balanceOf(accounts[1], tokenID3).then((bn) => bn.toNumber()));

  //CREATE A NEW PAYMENT ROUTE
  console.log("TESTING: PaymentRouter.getPaymentRouteID(), PaymentRouter.openPaymentRoute()");
  console.log("Running router.openPaymentRoute(recipients, commissions, routeTax)");
  await router.openPaymentRoute(recipients, commissions, routeTax, { from: seller });
  console.log("Running router.getPaymentRouteID(seller, recipients, commissions");
  routeID = await router.getPaymentRouteID(seller, recipients, commissions);
  console.log("routeID: " + routeID);
  console.log("Running router.openPaymentRoute([seller], [10000], routeTax)");
  await router.openPaymentRoute([seller], [10000], routeTax, { from: seller });
  console.log("Running router.getPaymentRouteID(seller, [seller], [100])");
  routeID2 = await router.getPaymentRouteID(seller, [seller], [10000]);
  console.log("routeID2: " + routeID2);

  //APPROVE MARKETPLACE TO HANDLE TOKENS
  console.log("TESTING: PazariToken and ERC20 approval");
  console.log("Pazari Tokens are automatically approved for transfer! Ain't that cool?");
  console.log("But ERC20 tokens are not. Running IERC20.approve():");
  await stablecoin.approve(market.address, approveAmount, { from: buyer });

  //PUT ITEM FOR SALE
  console.log("TESTING: Marketplace.createMarketItem()");
  itemID = await market.getNextItemID(); // Use other methods to obtain itemID for front-end!
  console.log("Running createMarketItem() for itemID " + itemID + ":");
  await market.createMarketItem(
    pazariToken.address,
    seller,
    tokenID,
    sellAmount1,
    price,
    paymentContract,
    isPush,
    true,
    routeID,
    itemLimit1,
    false,
    { from: seller },
  );
  console.log("createMarketItem() success");
  console.log(
    "itemID " + (await itemID) + " has " + (await pazariToken.balanceOf(market.address, tokenID)) + " units available",
  );
  itemID2 = await market.getNextItemID();
  console.log("Running createMarketItem() for itemID " + itemID2 + ":");
  await market.createMarketItem(
    pazariToken.address,
    seller,
    tokenID2,
    sellAmount2,
    price2,
    paymentContract,
    isPull,
    true,
    routeID,
    itemLimit2,
    false,
    { from: seller },
  );
  console.log("createMarketItem() success");
  console.log(
    "itemID " + itemID2 + " has " + (await pazariToken.balanceOf(market.address, tokenID2)) + " units available",
  );
  itemID3 = await market.getNextItemID(); // Use other methods to obtain itemID for front-end!
  console.log("Running createMarketItem() for itemID " + itemID3 + ":");
  await market.createMarketItem(
    pazariToken.address,
    seller,
    tokenID3,
    sellAmount3,
    price3,
    paymentContract,
    isPush,
    true,
    routeID2,
    itemLimit3,
    false,
    { from: seller },
  );
  console.log("createMarketItem() success");
  console.log(
    "itemID " +
      (await itemID3) +
      " has " +
      (await pazariToken.balanceOf(market.address, tokenID3)) +
      " units available",
  );

  /*
  //FETCH UNSOLD ITEM LIST
  //Use this to fetch a list of all MarketItem structs
  console.log("TESTING: Marketplace.getItemsForSale()")
  console.log("Running getItemsForSale():");
  let marketItems = await market.getItemsForSale();
  console.log(marketItems);
*/

  //FETCH UNSOLD ITEM IDS, THEN FETCH THEIR MARKET ITEMS
  //Use this to fetch a list of all MarketItem itemIDs, then choose which structs to display
  console.log("TESTING: Marketplace.getItemIDsForSale(), Marketplace.getMarketItems()");
  console.log("Running getItemIDsForSale():");
  let itemIDsForSale = await market.getItemIDsForSale();
  console.log("itemIDsForSale = " + (await itemIDsForSale));
  console.log("itemIDsForSale[0] = " + (await itemIDsForSale[0]));
  console.log("Running getMarketItems([itemIDsForSale[0]])");
  console.log(await market.getMarketItems([itemIDsForSale[0]]));
  console.log("Running getMarketItems(itemIDsForSale)");
  console.log(await market.getMarketItems(itemIDsForSale));

  //BUY TOKEN
  console.log("TESTING: Marketplace.buyMarketItem()");
  let allowance = stablecoin.allowance(buyer, market.address);
  console.log("Checking stablecoin allowance: " + web3.utils.fromWei(await allowance));
  console.log("Running buyMarketItem() for itemID 1:");
  await market.buyMarketItem(itemID, amountBuy, { from: buyer });
  console.log("Running buyMarketItem() for itemID 2:");
  await market.buyMarketItem(itemID2, amountBuy2, { from: buyer });
  console.log("Running buyMarketItem() for itemID 3:");
  await market.buyMarketItem(itemID3, amountBuy3, { from: buyer });

  //FETCH UNSOLD ITEM LIST AGAIN, MAKE SURE IT CLEARS CORRECTLY
  console.log("TESTING: Marketplace.getItemsForSale()");
  console.log("Running getItemsForSale():");
  marketItems = await market.getItemsForSale();
  console.log(marketItems);

  //CHECK BALANCES, MAKE SURE TOKEN AND VALUE ROUTED CORRECTLY
  console.log("Checking PazariToken balances for tokenID 1: (buyer: accounts[0], seller: accounts[1])");
  console.log("buyer: " + (await pazariToken.balanceOf(accounts[0], tokenID2).then((bn) => bn.toNumber())));
  console.log("seller: " + (await pazariToken.balanceOf(accounts[1], tokenID2).then((bn) => bn.toNumber())));
  console.log("Checking PazariToken balances for tokenID 2: (buyer: accounts[0], seller: accounts[1])");
  console.log("buyer: " + (await pazariToken.balanceOf(accounts[0], tokenID2).then((bn) => bn.toNumber())));
  console.log("seller: " + (await pazariToken.balanceOf(accounts[1], tokenID2).then((bn) => bn.toNumber())));
  console.log("Checking PazariToken balances for tokenID 3: (buyer: accounts[0], seller: accounts[1])");
  console.log("buyer: " + (await pazariToken.balanceOf(accounts[0], tokenID3).then((bn) => bn.toNumber())));
  console.log("seller: " + (await pazariToken.balanceOf(accounts[1], tokenID3).then((bn) => bn.toNumber())));
  console.log("Checking stablecoin balances:");
  console.log("Buyer: $" + web3.utils.fromWei(await stablecoin.balanceOf(buyer)));
  console.log("Seller: $" + web3.utils.fromWei(await stablecoin.balanceOf(seller)));
  console.log("Recipient 1: $" + web3.utils.fromWei(await stablecoin.balanceOf(accounts[2])));
  console.log("Recipient 2: $" + web3.utils.fromWei(await stablecoin.balanceOf(accounts[3])));
  console.log("Pazari Treasury: $" + web3.utils.fromWei(await stablecoin.balanceOf(accounts[4])));
  console.log("TESTING: PaymentRouter.pullTokens()");
  console.log("Pulling stablecoins from pullTokens() for accounts[1, 2, 3]:");
  await router.pullTokens(stablecoin.address, { from: accounts[1] });
  await router.pullTokens(stablecoin.address, { from: accounts[2] });
  await router.pullTokens(stablecoin.address, { from: accounts[3] });
  console.log("Checking stablecoin balances:");
  console.log("Buyer: $" + web3.utils.fromWei(await stablecoin.balanceOf(buyer)));
  console.log("Seller: $" + web3.utils.fromWei(await stablecoin.balanceOf(seller)));
  console.log("Recipient 1: $" + web3.utils.fromWei(await stablecoin.balanceOf(accounts[2])));
  console.log("Recipient 2: $" + web3.utils.fromWei(await stablecoin.balanceOf(accounts[3])));
  console.log("Pazari Treasury: $" + web3.utils.fromWei(await stablecoin.balanceOf(accounts[4])));

  console.log("TESTING: Marketplace.ownsToken():");
  console.log("Checking if buyer owns tokenID 1: " + (await market.ownsToken(buyer, pazariToken.address, tokenID)));
  console.log("Checking if seller owns tokenID 2: " + (await market.ownsToken(seller, pazariToken.address, tokenID2)));
  console.log(
    "Checking if accounts[8] owns tokenID 2: " + (await market.ownsToken(accounts[8], pazariToken.address, tokenID2)),
  );
  /*
   * To test:
   * - Multiple sellers and buyers
   * - More than 10 MarketItems
   * - Modifying MarketItems
   * - Restocking and pulling stock
   */
};
