/**
 * @notice These tests focus on the Marketplace contract, and as such also
 * test the PaymentRouter contract.
 * 
 * These tests more or less run through the basic functionality of Pazari:
 * - Tokenizing content (minting PazariTokens)
 * - Listing tokenized content (createMarketItem)
 * - Getting a list of all tokens for sale
 *
 */

const Marketplace = artifacts.require("Marketplace");
const PaymentRouter = artifacts.require("PaymentRouter");
const ERC20PresetMinterPauser = artifacts.require("ERC20PresetMinterPauser");
const PazariTokenMVP = artifacts.require("PazariTokenMVP");
const FactoryPazariTokenMVP = artifacts.require("FactoryPazariTokenMVP");
const PazariMVP = artifacts.require("PazariMVP");

module.exports = async function (deployer, network, accounts) {
  let buyer = accounts[4];
  let seller = accounts[1];
  let seller2 = accounts[2];
  let seller3 = accounts[3];
  let devWallet = accounts[0];
  let contractOwners = [];
  let minTax = 300;
  let maxTax = 1000;
  
  //DEPLOY MOCK STABLECOIN
  let tokenToMint = web3.utils.toWei("1000")
  let approveAmount = web3.utils.toWei(tokenToMint);
  // await deployer.deploy(ERC20, "Magic Internet Money", "MIM", web3.utils.toWei(tokenToMint), { from: buyer });
  await deployer.deploy(ERC20PresetMinterPauser, "Magic Internet Money", "MIM", { from: buyer });
  let stablecoin = await ERC20PresetMinterPauser.deployed();
  await stablecoin.mint(buyer, tokenToMint, {from: buyer});

  //DEPLOY PAYMENT ROUTER
  await deployer.deploy(PaymentRouter, devWallet, [devWallet], minTax, maxTax, { from: devWallet });
  let router = await PaymentRouter.deployed();

  //DEPLOY MARKETPLACE, then
  await deployer.deploy(Marketplace, router.address, [devWallet], {
    gas: 6700000,
    gasPrice: 8000000000,
    from: seller,
  });  
  let market = await Marketplace.deployed();
  
  //DEPLOY CONTRACT FACTORY
  await deployer.deploy(FactoryPazariTokenMVP);
  let factory = await FactoryPazariTokenMVP.deployed();
  
  //DEPLOY PAZARI MVP HELPER CONTRACT
  await deployer.deploy(PazariMVP, factory.address, market.address, router.address, stablecoin.address, [devWallet]);
  let pazariMVP = await PazariMVP.deployed();
  
  // ADD MARKETPLACE AND HELPER CONTRACT AS ADMINS FOR PR AND MP
  router.addAdmin(market.address, {from: devWallet});
  market.addAdmin(pazariMVP.address, {from: devWallet});


  console.log("stablecoin.address = " + (await stablecoin.address));
  console.log("market.address = " + (await market.address));
  console.log("router.address = " + (await router.address));
  console.log("factory.address = " + (await factory.address));
  console.log("pazariMVP.address = " + (await pazariMVP.address));

  //Function parameters for router.openPaymentRoute()
  // Note: All payment routes must be opened by devWallet or a Pazari helper contract,
  // so the original route creator will be devWallet rather than seller
  // Route 1 is a collaboration item that wants to pay custom tax of 3%
  // Route 2 is a single-seller item that wants to pay minTax
  // Route 3 is a collaboration item that wants to pay maxTax
  let recipients = [seller, seller2, seller3];
  let recipients2 = [seller];
  let recipients3 = [seller2, seller3]
  let commissions = [5000, 3150, 1850]; // 50%, 31.5%, 18.5%
  let commissions2 = [10000]; // 100%
  let commissions3 = [3000, 7000] // 30%, 70%
  let routeTax = 300;
  let routeTax2 = 100; // Test taxType == minTax logic
  let routeTax3 = 20000; // Test taxType == maxTax logic
  

  //Function parameters for market.CreateMarketItem():
  let itemID;
  let itemID2;
  let itemID3;
  let tokenID;
  let tokenID2;
  let tokenID3;
  // Price in stablecoins
  let price = web3.utils.toWei("100.00");
  let price2 = web3.utils.toWei("49.99");
  let price3 = web3.utils.toWei("9.99");
  // BalanceOf limit for token, 0 == no limit
  let itemLimit1 = 1;
  let itemLimit2 = 2;
  let itemLimit3 = 0;
  // Amount of item tokens to transfer to MP, 0 == transfer all tokens minted
  let sellAmount1 = 0;
  let sellAmount2 = 5;
  let sellAmount3 = 0;
  // Amount of items to buy, 0 == purchase itemLimit
  let buyAmount = 1;
  let buyAmount2 = 1;
  let buyAmount3 = 5;
  let paymentContract = stablecoin.address;
  let isPush = true;
  let isPush2 = true;
  let isPush3 = true;
  let routeID; // Assigned dynamically
  let routeID2;
  let routeID3;
  
  //Function parameters for token.createNewToken() and token.mint():
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
  
  //Used when estimating gas costs
  let amountOfGas;
  
  
  // Test AccessControl functions for Marketplace
  console.log("\n0. Testing AccessControlMP functions")
  let reason = "Testing";
  console.log("isAdmin[devWallet]: " + await market.isAdmin(devWallet));
  console.log("isAdmin[seller]: " + await market.isAdmin(seller));
  console.log("Adding seller as admin");
  console.log("Estimating gas: " + await market.addAdmin.estimateGas(seller, reason, {from: devWallet}));
  await market.addAdmin(seller, reason, {from: devWallet});
  console.log("isAdmin[seller]: " + await market.isAdmin(seller));
  console.log("Removing seller as admin");
  console.log("Estimating gas: " + await market.removeAdmin.estimateGas(seller, reason, {from: devWallet}));
  await market.removeAdmin(seller, {from: devWallet});
  console.log("isAdmin[seller]: " + await market.isAdmin(seller));

  //TEST BLACKLISTING
  console.log("\n0b. Testing toggleBlacklistAddress(seller)")
  reason = "Sold copyrighted material";
  console.log("isBlacklisted[seller]: " + await market.isBlacklisted(seller));
  console.log("Blacklisting seller : Inputs: seller = " + seller + ", reason = " + reason);
  console.log("Estimating gas: " + await market.toggleBlacklist.estimateGas(seller, reason, {from: devWallet}));
  await market.toggleBlacklist(seller, reason);
  console.log("isBlacklisted[seller]: " + await market.isBlacklisted(seller));
  reason = "Paid back debt"
  console.log("Whitelisting seller : Inputs: seller = " + seller + ", reason = " + reason);
  console.log("Estimating gas: " + await market.toggleBlacklist.estimateGas(seller, reason, {from: devWallet}));
  await market.toggleBlacklist(seller, reason);
  console.log("isBlacklisted[seller]: " + await market.isBlacklisted(seller));
  
  //CLONE NEW TOKEN CONTRACTS AND INSTANTIATE IT
  /**
   * @dev In Truffle, accessing a cloned contract is not as easy as accessing a deployed
   * contract. We have to calculate the cloned contract's address using .call(), then
   * use the returned address to instantiate the contract after it has been cloned.
   */
  //SELLER 1
  console.log("\n1. TESTING newPazariTokenMVP(contractOwners):")
  contractOwners = [seller, router.address, market.address, factory.address];
  let tokenAddress;
  let token;
  amountOfGas = await factory.newPazariTokenMVP.estimateGas(contractOwners, {from: seller});
  console.log("Estimating gas cost: " + amountOfGas);
  // Get address new token contract will be deployed to
  tokenAddress = await factory.newPazariTokenMVP.call(contractOwners);
  console.log("tokenAddress = " + tokenAddress);
  // Deploy new token contract
  await factory.newPazariTokenMVP(contractOwners, {from: seller});
  // Instantiate token contract at tokenAddress
  token = await PazariTokenMVP.at(tokenAddress);

  //SELLER 2
  contractOwners = [seller2, router.address, market.address, factory.address];
  tokenAddress2 = await factory.newPazariTokenMVP.call(contractOwners);
  console.log("tokenAddress2 = " + tokenAddress2);
  await factory.newPazariTokenMVP(contractOwners, {from: seller2});
  let token2 = await PazariTokenMVP.at(tokenAddress2)

  //SELLER 3
  contractOwners = [seller3, router.address, market.address, factory.address];
  tokenAddress3 = await factory.newPazariTokenMVP.call(contractOwners);
  console.log("tokenAddress3 = " + tokenAddress3);
  await factory.newPazariTokenMVP(contractOwners, {from: seller3});
  let token3 = await PazariTokenMVP.at(tokenAddress3)

  //CHECK INITIAL STABLECOIN BALANCES
  console.log("\n2. Checking initial stablecoin balances");
  console.log("Buyer: $" + web3.utils.fromWei(await stablecoin.balanceOf(buyer)));
  console.log("Seller: $" + web3.utils.fromWei(await stablecoin.balanceOf(seller)));
  console.log("Seller2: $" + web3.utils.fromWei(await stablecoin.balanceOf(seller2)));
  console.log("Seller3: $" + web3.utils.fromWei(await stablecoin.balanceOf(seller3)));
  console.log("Pazari Treasury: $" + web3.utils.fromWei(await stablecoin.balanceOf(devWallet)));

  //MINT ITEM TOKENS
  console.log("\n3. TESTING: PazariTokenMVP.createNewToken()");
  amountOfGas = await token.createNewToken.estimateGas(tokenURI, amountMint, supplyCap1, isMintable1, { from: seller });
  console.log("Estimating gas cost: " + amountOfGas);
  console.log("Creating new item tokens");
  tokenID = await token.createNewToken.call(tokenURI, amountMint, supplyCap1, isMintable1, { from: seller })
  tokenID2 = await token2.createNewToken.call(tokenURI, amountMint2, supplyCap2, isMintable2, { from: seller2 });  
  tokenID3 = await token3.createNewToken.call(tokenURI, amountMint3, supplyCap3, isMintable3, { from: seller3 });
  
  console.log("tokenID " + tokenID + " is a standard edition token with supply of " + amountMint);
  await token.createNewToken(tokenURI, amountMint, supplyCap1, isMintable1, { from: seller });
  console.log("tokenID " + tokenID2 + " is a limited edition item, with supply of " + amountMint2);
  await token2.createNewToken(tokenURI, amountMint2, supplyCap2, isMintable2, { from: seller2 });
  console.log("tokenID " + tokenID3 + " is a standard edition item, with supply of " + amountMint3);
  await token3.createNewToken(tokenURI, amountMint3, supplyCap3, isMintable3, { from: seller3 });

  //CHECK INITIAL PAZARI TOKEN BALANCES
  console.log("\n4. Checking PazariToken balances");
  console.log("Checking token balances for tokenID 1: (buyer, seller)");
  console.log("buyer: " + await token.balanceOf(buyer, tokenID).then((bn) => bn.toNumber()));
  console.log("seller: " + await token.balanceOf(seller, tokenID).then((bn) => bn.toNumber()));
  console.log("Checking token balances for tokenID 2: (buyer, seller)");
  console.log("buyer: " + await token2.balanceOf(buyer, tokenID2).then((bn) => bn.toNumber()));
  console.log("seller2: " + await token2.balanceOf(seller2, tokenID2).then((bn) => bn.toNumber()));
  console.log("Checking token balances for tokenID 3: (buyer, seller)");
  console.log("buyer: " + await token3.balanceOf(buyer, tokenID3).then((bn) => bn.toNumber()));
  console.log("seller2: " + await token3.balanceOf(seller3, tokenID3).then((bn) => bn.toNumber()));

  /** CREATE A NEW PAYMENT ROUTE
   * Because PR is restricted to only Pazari-owned addresses, devWallet is substituting
   * for PazariMVP
   */
  console.log("\n5. TESTING: PaymentRouter.getPaymentRouteID(), PaymentRouter.openPaymentRoute()");
  console.log("All recipients, commissions, and routeTax values for all payment routes:")
  console.log("recipients: " + recipients); // Payment route 1
  console.log("commissions: " + commissions);
  console.log("routeTax: " + routeTax);
  console.log("recipients2: " + recipients2); // Payment route 2
  console.log("commissions2: " + commissions2);
  console.log("routeTax2: " + routeTax2);
  console.log("recipients3: " + recipients3); // Payment route 3
  console.log("commissions3: " + commissions3);
  console.log("routeTax3: " + routeTax3);
  console.log("Running router.openPaymentRoute(recipients, commissions, routeTax, { from: devWallet })");
  amountOfGas = await router.openPaymentRoute.estimateGas(recipients, commissions, routeTax, { from: devWallet });
  console.log("Estimating gas cost: " + amountOfGas);
  // Payment route 1
  await router.openPaymentRoute(recipients, commissions, routeTax, { from: devWallet });
  console.log("Running router.getPaymentRouteID(devWallet, recipients, commissions");
  routeID = await router.getPaymentRouteID(devWallet, recipients, commissions);
  console.log("routeID: " + routeID);
  console.log(await router.getPaymentRoute(routeID));
  console.log("Running router.openPaymentRoute(recipients2, commissions2, routeTax2, { from: devWallet })");
  // Payment route 2
  await router.openPaymentRoute(recipients2, commissions2, routeTax2, { from: devWallet });
  console.log("Running router.getPaymentRouteID(devWallet, recipients2, commissions2)");
  routeID2 = await router.getPaymentRouteID(devWallet, recipients2, commissions2);
  console.log("routeID2: " + routeID2);
  console.log(await router.getPaymentRoute(routeID2));
  console.log("Running router.openPaymentRoute(recipients3, commissions3, routeTax3, { from: devWallet })");
  // Payment route 3
  await router.openPaymentRoute(recipients3, commissions3, routeTax3, { from: devWallet });
  console.log("Running router.getPaymentRouteID(devWallet, recipients3, commissions3)");
  routeID3 = await router.getPaymentRouteID(devWallet, recipients3, commissions3);
  console.log("routeID23: " + routeID3);
  console.log(await router.getPaymentRoute(routeID3));

  //APPROVE MARKETPLACE TO HANDLE TOKENS
  console.log("\n6. TESTING: PazariToken and ERC20 approval");
  console.log("Pazari Tokens are automatically approved for transfer! Ain't that cool?");
  console.log("But ERC20 tokens are not. Running IERC20.approve():");
  await stablecoin.approve(market.address, approveAmount, { from: buyer });
  
  //PUT ITEMS FOR SALE
  console.log("\n7. TESTING: Marketplace.createMarketItem()");

  // Item 1
  itemID = await market.createMarketItem.call(
    token.address,
    tokenID,
    sellAmount1,
    price,
    paymentContract,
    routeID,
    { from: seller }
  );
  console.log("Running createMarketItem() for itemID " + itemID + ":");
  console.log("Estimating gas: " + await market.createMarketItem.estimateGas(
    token.address,
    tokenID,
    sellAmount1,
    price,
    paymentContract,
    routeID,
    { from: seller }
  ));
  await market.createMarketItem(
    token.address,
    tokenID,
    sellAmount1,
    price,
    paymentContract,
    routeID,
    { from: seller }
  );
  console.log("createMarketItem() success");
  console.log(
    "itemID " + itemID + " has " + (await token.balanceOf(market.address, tokenID)) + " units available",
  );

  // Item 2
  itemID2 = await market.createMarketItem.call(
      tokenAddress2,
      tokenID2,
      sellAmount2,
      price2,
      paymentContract,
      routeID2,
      { from: seller2 }
    );    
  console.log("Running createMarketItem() for itemID " + itemID2 + ":");
  console.log("Estimating gas: " + await market.createMarketItem.estimateGas(
    tokenAddress2,
    tokenID2,
    sellAmount2,
    price2,
    paymentContract,
    routeID2,
    { from: seller2 }
  ));
  await market.createMarketItem(
    tokenAddress2,
    tokenID2,
    sellAmount2,
    price2,
    paymentContract,
    routeID2,
    { from: seller2 }
  );
  console.log("createMarketItem() success");
  console.log(
    "itemID " + itemID2 + " has " + (await token.balanceOf(market.address, tokenID2)) + " units available",
  );

  // Item 3
  itemID3 = await market.createMarketItem.call(
      token3.address,
      tokenID3,
      sellAmount3,
      price3,
      paymentContract,
      routeID3,
      { from: seller3 }
    );  
    console.log("Running createMarketItem() for itemID " + itemID3 + ":");
    console.log("Estimating gas: " + await market.createMarketItem.estimateGas(
      token3.address,
      tokenID3,
      sellAmount3,
      price3,
      paymentContract,
      routeID3,
      { from: seller3 }
    ));
    await market.createMarketItem(
      token3.address,
      tokenID3,
      sellAmount3,
      price3,
      paymentContract,
      routeID3,
      { from: seller3 }
  );
  console.log("createMarketItem() success");
  console.log("itemID " + (await itemID3) + " has " +
    (await token.balanceOf(market.address, tokenID3)) +
    " units available",
  );

/*
  //FETCH UNSOLD ITEM LIST DIRECTLY
  //Use this to fetch a list of all MarketItem structs
  console.log("TESTING: Marketplace.getItemsForSale()")
  console.log("Running getItemsForSale():");
  let marketItems = await market.getItemsForSale();
  console.log(marketItems);
*/

  //FETCH UNSOLD ITEM IDS, THEN FETCH THEIR MARKET ITEMS
  //Use this to fetch a list of all MarketItem itemIDs, then choose which structs to display
  console.log("\n8. TESTING: Marketplace.getItemIDsForSale(), Marketplace.getMarketItems()");
  console.log("Running getItemIDsForSale():");
  let itemIDsForSale = await market.getItemIDsForSale();
  console.log("itemIDsForSale = " + (await itemIDsForSale));
  console.log("Running getMarketItems(itemIDsForSale)");
  console.log(await market.getMarketItems(itemIDsForSale));

  
  //BUY TOKEN
  console.log("\n9. TESTING: Marketplace.buyMarketItem()");
  let allowance = stablecoin.allowance(buyer, market.address);
  console.log("Checking stablecoin allowance: " + web3.utils.fromWei(await allowance));

  console.log("\nEstimating each gas cost for buyMarketItem()")
  amountOfGas = await market.buyMarketItem.estimateGas(itemID, buyAmount, { from: buyer });
  console.log("Inputs: itemID = " + itemID + ", buyAmount = " + buyAmount + "from: buyer" );
  console.log("ItemID 1: " + amountOfGas);
  amountOfGas = await market.buyMarketItem.estimateGas(itemID2, buyAmount2, { from: buyer });
  console.log("Inputs: itemID2 = " + itemID2 + ", buyAmount = " + buyAmount2 + "from: buyer" );
  console.log("ItemID 2: " + amountOfGas);
  amountOfGas = await market.buyMarketItem.estimateGas(itemID3, buyAmount3, { from: buyer });
  console.log("Inputs: itemID = " + itemID3 + ", buyAmount = " + buyAmount3 + "from: buyer" );
  console.log("ItemID3: " + amountOfGas);

  console.log("Running buyMarketItem() for itemID 1:");
  await market.buyMarketItem(itemID, buyAmount, { from: buyer });
  console.log("Running buyMarketItem() for itemID 2: ItemID 2 will be sold out");
  await market.buyMarketItem(itemID2, buyAmount2, { from: buyer });
  console.log("Running buyMarketItem() for itemID 3:");
  await market.buyMarketItem(itemID3, buyAmount3, { from: buyer });

  //FETCH UNSOLD ITEM LIST AGAIN, MAKE SURE IT CLEARED SOLD OUT ORDERS CORRECTLY
  console.log("\n10. TESTING: Marketplace.getItemsForSale()");
  console.log("Running getItemsForSale():");
  marketItems = await market.getItemsForSale();
  console.log(marketItems);

  //CHECK BALANCES, MAKE SURE TOKEN AND VALUE ROUTED CORRECTLY
  console.log("\n11. Checking PazariToken balances for tokenID 1: (buyer, seller)");
  console.log("buyer: " + (await token.balanceOf(buyer, tokenID2).then((bn) => bn.toNumber())));
  console.log("seller: " + (await token.balanceOf(seller, tokenID2).then((bn) => bn.toNumber())));
  
  console.log("Checking PazariToken balances for tokenID 2: (buyer, seller)");
  console.log("buyer: " + (await token.balanceOf(buyer, tokenID2).then((bn) => bn.toNumber())));
  console.log("seller2: " + (await token.balanceOf(seller2, tokenID2).then((bn) => bn.toNumber())));
  
  console.log("Checking PazariToken balances for tokenID 3: (buyer, seller)");
  console.log("buyer: " + (await token.balanceOf(buyer, tokenID3).then((bn) => bn.toNumber())));
  console.log("seller3: " + (await token.balanceOf(seller3, tokenID3).then((bn) => bn.toNumber())));
  
  console.log("Tokens available for collection:");
  console.log("Seller1: $" + web3.utils.fromWei(await router.getPaymentBalance(seller, stablecoin.address, {from: seller})));
  console.log("Seller2: $" + web3.utils.fromWei(await router.getPaymentBalance(seller2, stablecoin.address, {from: seller2})));
  console.log("Seller3: $" + web3.utils.fromWei(await router.getPaymentBalance(seller3, stablecoin.address, {from: seller3})));

  console.log("Checking stablecoin balances:");
  console.log("Buyer: $" + web3.utils.fromWei(await stablecoin.balanceOf(buyer)));
  console.log("Seller: $" + web3.utils.fromWei(await stablecoin.balanceOf(seller)));
  console.log("Seller2: $" + web3.utils.fromWei(await stablecoin.balanceOf(seller2)));
  console.log("Seller3: $" + web3.utils.fromWei(await stablecoin.balanceOf(seller3)));
  console.log("Pazari Treasury: $" + web3.utils.fromWei(await stablecoin.balanceOf(devWallet)));
  console.log("Treasury tax is removed *before* commissions are distributed");

  /*
  console.log("\n11. TESTING: PaymentRouter.getPaymentRoute(routeID, routeID2, routeID3)");
  console.log("Checking routeID recipients");
  console.log(await router.getPaymentRoute(routeID));
  console.log("Checking routeID2 recipients");
  console.log(await router.getPaymentRoute(routeID2));
  console.log("Checking routeID3 recipients");
  console.log(await router.getPaymentRoute(routeID3));
*/  

  //TEST PULLING STOCK:
  console.log("\n13a. TESTING: pullStock()");
  let item = await market.getMarketItems([itemID]);
  let pullAmount = 100000;
  let itemAmount = item[0].amount;
  console.log("ItemID 1 stock: " + await itemAmount);
  console.log("Running pullStock(itemID, pullAmount)");
  console.log("Estimating gas: " + await market.pullStock.estimateGas(itemID, pullAmount, { from: seller }));
  await market.pullStock(itemID, pullAmount, { from: seller });
  item = await market.getMarketItems([itemID]);
  console.log("ItemID 1 stock: " + await item[0].amount);
  
  //TEST RESTOCKING:
  console.log("\n13b. TESTING: restockItem()");
  let restockAmount = 50;
  item = await market.getMarketItems([itemID2]);
  itemAmount = item[0].amount
  console.log("ItemID " + await item[0].itemID + " stock: " + await itemAmount);
  console.log("Marketplace ItemID2 balanceOf: " + await token2.balanceOf(market.address, tokenID2));
  console.log("Seller2 balanceOf: " + await token2.balanceOf(seller2, tokenID2));
  console.log("Running restockItem(itemID, restockAmount), restockAmount = " + restockAmount);
  console.log("Estimating gas: " + await market.restockItem.estimateGas(itemID2, restockAmount, { from: seller2 }));
  await market.restockItem(itemID2, restockAmount, { from: seller2 });
  item = await market.getMarketItems([itemID2]);
  itemAmount = item[0].amount;
  console.log("ItemID " + item[0].itemID + " stock: " + await itemAmount);
  console.log("Marketplace ItemID2 balanceOf: " + await token2.balanceOf(market.address, tokenID2));

  //TEST MODIFYING MARKET ITEMS
  price = web3.utils.toWei("59.99");
  isPush = false; 
  isPush2 = false;
  isPush3 = false;
  itemLimit1 = 2;
  // ITEM 1
  console.log("\n14. TESTING: modifyMarketItem()")
  console.log("Let's change all three items to use pull routes, and then buy them all")
  console.log("Getting ItemID 1: ")
  console.log(await market.getMarketItems([itemID]));
  console.log("Running modifyMarketItem()")
  console.log("Inputs: itemID = " 
  + itemID + ", \nprice = ",
  + price + ", \nstablecoin address =  ",
  + stablecoin.address + ",\npush/pull = ",
  + isPush + ", \nrouteID = ",
  + routeID + ", \nitem limit = ",
  + itemLimit1 + ",\n {from: seller}"
  );

  console.log("Estimating gas: " 
  + await market.modifyMarketItem
  .estimateGas(
    itemID, 
    price, 
    stablecoin.address, 
    isPush, 
    routeID, 
    itemLimit1,
    {from: seller}
  ));
  await market.modifyMarketItem(
    itemID, 
    price, 
    stablecoin.address, 
    isPush, 
    routeID, 
    itemLimit1,
    {from: seller}
  );
  console.log("Modification done, getting itemID " + itemID);
  console.log(await market.getMarketItems([itemID]));

  // ITEM 2
  console.log("Running modifyMarketItem()");
  console.log("Inputs: itemID = " 
  + itemID2 + ", \nprice = ",
  + price2 + ", \nstablecoin address =  ",
  + stablecoin.address + ", \npush/pull = ",
  + isPush2 + ", \nrouteID = ",
  + routeID2 + ", \nitem limit = ",
  + itemLimit2 + ", \n{from: seller2}"
  );
  console.log("isItemAdmin[seller2]: " + await market.isItemAdmin(itemID2, seller2));
  console.log("Estimating gas: " 
  + await market.modifyMarketItem
  .estimateGas(
    itemID2, 
    price2, 
    stablecoin.address, 
    isPush2, 
    routeID2, 
    itemLimit2,
    {from: seller2}
  ));
  await market.modifyMarketItem(
    itemID2, 
    price2, 
    stablecoin.address, 
    isPush2, 
    routeID2, 
    itemLimit2,
    {from: seller2}
  );
  console.log("Getting itemID " + itemID2);
  console.log(await market.getMarketItems([itemID2]));

  //ITEM 3
  console.log("Running modifyMarketItem()");
  console.log("isItemAdmin[seller3]: " + await market.isItemAdmin(itemID3, seller3));
  console.log("Inputs: itemID = " 
  + itemID3 + ", \nprice = ",
  + price3 + ", \nstablecoin address =  ",
  + stablecoin.address + ", \npush/pull = ",
  + isPush3 + ", \nrouteID = ",
  + routeID3 + ", \nitem limit = ",
  + itemLimit3 + ", \n{from: seller3}"
  );
  console.log("Estimating gas: " 
  + await market.modifyMarketItem
  .estimateGas(
    itemID3, 
    price3, 
    stablecoin.address, 
    isPush3, 
    routeID3, 
    itemLimit3,
    {from: seller3}
  ));
  await market.modifyMarketItem(
    itemID3, 
    price3, 
    stablecoin.address, 
    isPush3, 
    routeID3, 
    itemLimit3,
    {from: seller3}
  );
  console.log("Getting itemID " + itemID3);
  console.log(await market.getMarketItems([itemID3]));

  //PLACE BUY ORDERS SO PAYMENTS NOW USE HOLD TOKENS
  console.log("Placing buy orders for itemIDs 1, 2, 3");
  console.log(await market.getMarketItems([itemID]));
  buyAmount = 5;
  await market.buyMarketItem(itemID, buyAmount, { from: buyer });
  await market.buyMarketItem(itemID2, buyAmount2, { from: buyer });
  await market.buyMarketItem(itemID3, buyAmount3, { from: buyer });
  console.log("Done. There should now be money available to collect from pullTokens");
  console.log("Tokens available for collection:");
  console.log("Seller1: $" + web3.utils.fromWei(await router.getPaymentBalance(seller, stablecoin.address, {from: seller})));
  console.log("Seller2: $" + web3.utils.fromWei(await router.getPaymentBalance(seller2, stablecoin.address, {from: seller2})));
  console.log("Seller3: $" + web3.utils.fromWei(await router.getPaymentBalance(seller3, stablecoin.address, {from: seller3})));


  //TEST PULL TOKENS
  console.log("\n12. TESTING: PaymentRouter.pullTokens()");
  console.log("Pulling stablecoins from pullTokens() for seller, seller2, seller3:");
  await router.pullTokens(stablecoin.address, { from: seller });
  await router.pullTokens(stablecoin.address, { from: seller2 });
  await router.pullTokens(stablecoin.address, { from: seller3 });
  console.log("Tokens available for collection:")
  console.log("Seller1: $" + web3.utils.fromWei(await router.getPaymentBalance(seller, stablecoin.address, {from: seller})));
  console.log("Seller2: $" + web3.utils.fromWei(await router.getPaymentBalance(seller2, stablecoin.address, {from: seller2})));
  console.log("Seller3: $" + web3.utils.fromWei(await router.getPaymentBalance(seller3, stablecoin.address, {from: seller3})));
  console.log("\nChecking stablecoin balances:");
  console.log("Buyer: $" + web3.utils.fromWei(await stablecoin.balanceOf(buyer)));
  console.log("Seller: $" + web3.utils.fromWei(await stablecoin.balanceOf(seller)));
  console.log("Seller2: $" + web3.utils.fromWei(await stablecoin.balanceOf(seller2)));
  console.log("Seller3: $" + web3.utils.fromWei(await stablecoin.balanceOf(seller3)));
  console.log("Pazari Treasury: $" + web3.utils.fromWei(await stablecoin.balanceOf(devWallet)));

  //TEST TOKEN OWNERSHIP VERIFICATION
  console.log("\n13. TESTING: Marketplace.ownsToken():");
  console.log("Checking if buyer owns tokenID 1: " + (await market.ownsTokens(buyer, [1])));
  console.log("Checking if seller owns tokenID 2: " + (await market.ownsTokens(seller, [2])));
  console.log("Checking if accounts[8] owns tokenID 2 (it does not): " + (await market.ownsTokens(accounts[8], [3])));

  //TOGGLE FOR SALE
  console.log("\n14. TESTING: toggleForSale(itemID)");
  item = await market.getMarketItems([itemID]);
  forSale = item[0].forSale;
  console.log("Item for sale? " + forSale);
  console.log("Running toggleForSale(itemID)");
  console.log("Estimating gas: " + await market.toggleForSale.estimateGas(itemID, { from: seller }));
  await market.toggleForSale(itemID, { from: seller });
  item = await market.getMarketItems([itemID]);
  forSale = item[0].forSale;
  buyAmount = 2;
  console.log("Item for sale? " + forSale);
  //console.log("Attempt to purchase a not-for-sale item: ");
  //await market.buyMarketItem(itemID, buyAmount);
  console.log("Running toggleForSale(itemID)");
  await market.toggleForSale(itemID, { from: seller });
  item = await market.getMarketItems([itemID]);
  forSale = item[0].forSale;
  buyAmount = 2;
  console.log("Item for sale? " + forSale);
  
  //DELETE ITEM
  console.log("\n15. TESTING: deleteMarketItem()")
  console.log("Pull all item stock for itemID " + itemID);
  await market.pullStock(itemID, 0)
  console.log("Deleting itemID " + itemID);
  console.log("Estimating gas: " + await market.deleteMarketItem.estimateGas(itemID, { from: seller }));
  await market.deleteMarketItem(itemID, { from: seller })
  console.log("Done, now getting itemID " + itemID)
  console.log(await market.getMarketItems([itemID]));

  console.log("TESTING COMPLETE")
};
