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
  let treasury = accounts[5];
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

  console.log("stablecoin.address = " + (await stablecoin.address));
  console.log("router.address = " + (await router.address));

  //Function parameters for router.openPaymentRoute()
  // Note: All payment routes must be opened by devWallet or a Pazari helper contract,
   // so the original route creator will be devWallet rather than seller. Test the
   // functionality of _msgSender() via PazariMVP and Marketplace tests
  // Route 1 is a collaboration item that wants to pay custom tax of 3%
  // Route 2 is a collaboration item that wants to pay minTax
  // Route 3 is a single-seller item that wants to pay maxTax
  let recipients = [seller, seller2, seller3];
  let recipients2 = [seller, seller2];
  let recipients3 = [seller2]
  let commissions = [5000, 3150, 1850]; // 50%, 31.5%, 18.5%
  let commissions2 = [3000, 7000]; // 30%, 70%
  let commissions3 = [10000]; // 100%
  let routeTax = 750;
  let routeTax2 = 0; // Test taxType == minTax logic
  let routeTax3 = maxTax + 1; // Test taxType == maxTax logic
  let routeID;
  let routeID2;
  let routeID3;
  console.log("recipients: " + recipients);
  console.log("commissions: " + commissions);
  console.log("routeTax: " + routeTax)
  console.log("recipients2: " + recipients);
  console.log("commissions2: " + commissions);
  console.log("routeTax: " + routeTax2)
  console.log("recipients3: " + recipients);
  console.log("commissions3: " + commissions);
  console.log("routeTax: " + routeTax3)

  // Prices in stablecoins
  let price = web3.utils.toWei("100.00");
  let price2 = web3.utils.toWei("49.99");
  let price3 = web3.utils.toWei("9.99");

  //Used when estimating gas costs
  let amountOfGas;

  //***BEGIN TESTS***\\
  
  // Test AccessControl functions for PaymentRouter
  console.log("\n1. Testing AccessControl functions")
  console.log("isAdmin[devWallet]: " + await router.isAdmin(devWallet));
  console.log("isAdmin[seller]: " + await router.isAdmin(seller));
  console.log("Adding seller as admin");
  console.log("Estimating gas cost: " + await router.addAdmin.estimateGas(seller, {from: devWallet}))
  await router.addAdmin(seller, {from: devWallet});
  console.log("isAdmin[seller]: " + await router.isAdmin(seller));
  console.log("Removing seller as admin");
  console.log("Estimating gas cost: " + await router.removeAdmin.estimateGas(seller, {from: devWallet}))
  await router.removeAdmin(seller, {from: devWallet});
  console.log("isAdmin[seller]: " + await router.isAdmin(seller));

  //CHECK INITIAL STABLECOIN BALANCES
  console.log("\n2. Checking initial stablecoin balances");
  console.log("Buyer: $" + web3.utils.fromWei(await stablecoin.balanceOf(buyer)));
  console.log("Seller: $" + web3.utils.fromWei(await stablecoin.balanceOf(seller)));
  console.log("Seller2: $" + web3.utils.fromWei(await stablecoin.balanceOf(seller2)));
  console.log("Seller3: $" + web3.utils.fromWei(await stablecoin.balanceOf(seller3)));
  console.log("Pazari Treasury: $" + web3.utils.fromWei(await stablecoin.balanceOf(devWallet)));

  //CREATE A NEW PAYMENT ROUTE
  console.log("\n3. TESTING: getPaymentRouteID(), openPaymentRoute(), getPaymentRoute()");

  // PAYMENT ROUTE 1
  console.log("Running router.openPaymentRoute(recipients, commissions, routeTax, { from: devWallet })");
  amountOfGas = await router.openPaymentRoute.estimateGas(recipients, commissions, routeTax, { from: devWallet });
  console.log("Estimating gas cost: " + amountOfGas);
  await router.openPaymentRoute(recipients, commissions, routeTax, { from: devWallet });
  console.log("Running router.getPaymentRoute(devWallet, recipients, commissions");
  routeID = await router.getPaymentRouteID(devWallet, recipients, commissions);
  console.log("\nrouteID: " + routeID);
  console.log(await router.getPaymentRoute(routeID));

  // PAYMENT ROUTE 2
  console.log("Running router.openPaymentRoute(recipients2, commissions2, routeTax2, { from: devWallet })");
  amountOfGas = await router.openPaymentRoute.estimateGas(recipients2, commissions2, routeTax2, { from: devWallet });
  console.log("Estimating gas cost: " + amountOfGas);
  await router.openPaymentRoute(recipients2, commissions2, routeTax2, { from: devWallet });
  console.log("Running router.getPaymentRoute(devWallet, recipients2, commissions2)");
  routeID2 = await router.getPaymentRouteID(devWallet, recipients2, commissions2);
  console.log("\nrouteID2: " + routeID2);
  console.log(await router.getPaymentRoute(routeID2));
  
  // PAYMENT ROUTE 3
  console.log("Running router.openPaymentRoute(recipients3, commissions3, routeTax3, { from: devWallet })");
  amountOfGas = await router.openPaymentRoute.estimateGas(recipients3, commissions3, routeTax3, { from: devWallet });
  console.log("Estimating gas cost: " + amountOfGas);
  await router.openPaymentRoute(recipients3, commissions3, routeTax3, { from: devWallet });
  console.log("Running router.getPaymentRouteID(devWallet, recipients3, commissions3)");
  routeID3 = await router.getPaymentRouteID(devWallet, recipients3, commissions3);
  console.log("\nrouteID3: " + routeID3);
  console.log(await router.getPaymentRoute(routeID3));

  //TEST PAYMENT ROUTE GETTER
  console.log("\n4. TESTING: PaymentRouter.getPaymentRoute(routeID, routeID2, routeID3)");
  console.log("routeID: ");
  console.log(await router.getPaymentRoute(routeID));
  console.log("routeID2:");
  console.log(await router.getPaymentRoute(routeID2));
  console.log("routeID3:");
  console.log(await router.getPaymentRoute(routeID3));    

  //APPROVE PAYMENT ROUTER TO HANDLE TOKENS
  console.log("\n5. RUNNING: ERC20 approval");
  await stablecoin.approve(router.address, approveAmount, { from: buyer });

  /*
  //CHECK BALANCES  
  console.log("Checking stablecoin balances:");
  console.log("Buyer: $" + web3.utils.fromWei(await stablecoin.balanceOf(buyer)));
  console.log("Seller: $" + web3.utils.fromWei(await stablecoin.balanceOf(seller)));
  console.log("Seller2: $" + web3.utils.fromWei(await stablecoin.balanceOf(seller2)));
  console.log("Seller3: $" + web3.utils.fromWei(await stablecoin.balanceOf(seller3)));
  console.log("Pazari Treasury: $" + web3.utils.fromWei(await stablecoin.balanceOf(devWallet)));
  */

  //TEST PUSH FUNCTION
  console.log("\n.6 TESTING: pushTokens()")
  console.log("\n Estimating gas for routeID 1: " + await router.pushTokens.estimateGas(routeID, stablecoin.address, buyer, price, {from: devWallet}));
  await router.pushTokens(routeID, stablecoin.address, buyer, price, {from: devWallet});
  console.log("\n Estimating gas for routeID 2: " + await router.pushTokens.estimateGas(routeID2, stablecoin.address, buyer, price, {from: devWallet}));
  await router.pushTokens(routeID2, stablecoin.address, buyer, price, {from: devWallet});
  console.log("\n Estimating gas for routeID 3: " + await router.pushTokens.estimateGas(routeID3, stablecoin.address, buyer, price, {from: devWallet}));
  await router.pushTokens(routeID3, stablecoin.address, buyer, price, {from: devWallet});

  //TEST HOLD FUNCTION
  console.log("\n7. TESTING: PaymentRouter.holdTokens()");
  console.log("Holding stablecoins from holdTokens() for seller, seller2, seller3:");
  console.log("\n Estimating gas for seller: " + await router.holdTokens.estimateGas(routeID, stablecoin.address, buyer, price, {from: devWallet}));
  await router.holdTokens(routeID, stablecoin.address, buyer, price, {from: devWallet});
  console.log("\n Estimating gas for seller2: " + await router.holdTokens.estimateGas(routeID2, stablecoin.address, buyer, price, {from: devWallet}));
  await router.holdTokens(routeID2, stablecoin.address, buyer, price, {from: devWallet});
  console.log("\n Estimating gas for seller3: " + await router.holdTokens.estimateGas(routeID3, stablecoin.address, buyer, price, {from: devWallet}));
  await router.holdTokens(routeID3, stablecoin.address, buyer, price, {from: devWallet});
  console.log("\nChecking stablecoin balances:");
  console.log("Tokens available for collection:")
  
  
  //TEST PULL FUNCTION
  console.log("\n8. TESTING: PaymentRouter.pullTokens()");
  console.log("Pulling stablecoins from pullTokens() for seller, seller2, seller3:");
  console.log("\n Estimating gas for seller: " + await router.pullTokens.estimateGas(stablecoin.address, { from: seller }));
  await router.pullTokens(stablecoin.address, { from: seller });
  console.log("\n Estimating gas for seller2: " + await router.pullTokens.estimateGas(stablecoin.address, { from: seller2 }));
  await router.pullTokens(stablecoin.address, { from: seller2 });
  console.log("\n Estimating gas for seller3: " + await router.pullTokens.estimateGas(stablecoin.address, { from: seller3 }));
  await router.pullTokens(stablecoin.address, { from: seller3 });
  console.log("\nChecking stablecoin balances:");
  console.log("Tokens available for collection:")

  //CHECK BALANCES, MAKE SURE TOKENS ROUTED CORRECTLY  
  console.log("\n9. TESTING: getPaymentBalance() for seller, seller2, seller3, buyer")
  console.log("Seller1: $" + web3.utils.fromWei(await router.getPaymentBalance(seller, stablecoin.address, {from: seller})));
  console.log("Seller2: $" + web3.utils.fromWei(await router.getPaymentBalance(seller2, stablecoin.address, {from: seller2})));
  console.log("Seller3: $" + web3.utils.fromWei(await router.getPaymentBalance(seller3, stablecoin.address, {from: seller3})));
  console.log("Seller3: $" + web3.utils.fromWei(await router.getPaymentBalance(buyer, stablecoin.address, {from: buyer})));
  console.log("Buyer: $" + web3.utils.fromWei(await stablecoin.balanceOf(buyer)));
  console.log("Seller: $" + web3.utils.fromWei(await stablecoin.balanceOf(seller)));
  console.log("Seller2: $" + web3.utils.fromWei(await stablecoin.balanceOf(seller2)));
  console.log("Seller3: $" + web3.utils.fromWei(await stablecoin.balanceOf(seller3)));
  console.log("Pazari Treasury: $" + web3.utils.fromWei(await stablecoin.balanceOf(devWallet)));
  
  //TEST DISABLING/ENABLING PAYMENT ROUTE
  console.log("\n11. TESTING: togglePaymentRoute()")
  console.log("Estimating gas cost for routeID 1 (true => false): " + await router.togglePaymentRoute.estimateGas(routeID, {from: devWallet}));
  await router.togglePaymentRoute(routeID, {from: devWallet});
  console.log("Estimating gas cost for routeID 1 (false => true): " + await router.togglePaymentRoute.estimateGas(routeID, {from: devWallet}));
  await router.togglePaymentRoute(routeID, {from: devWallet});
  
/*
  // This should cause a revert if it's working properly
  console.log("Disabiling routeID 2 and pushing tokens:")
  await router.togglePaymentRoute(routeID2, {from: devWallet});
  await router.pushTokens(routeID2, stablecoin.address, buyer, price2, {from: devWallet});
  await router.holdTokens(routeID2, stablecoin.address, buyer, price2, {from: devWallet});
*/
  console.log("\n12. TESTING: adjustRouteTax() and logic for custom taxType")
  let route = await router.getPaymentRoute(routeID);
  routeTax = route.routeTax;
  let taxType;
  console.log("Current routeTax for routeID: " + routeTax)
  console.log("Adjusting routeTax to 5.00%");
  console.log("Estimating gas cost: " + await router.adjustRouteTax.estimateGas(routeID, 500));
  await router.adjustRouteTax(routeID, 500);
  route = await router.getPaymentRoute(routeID);
  routeTax = route.routeTax;
  taxType = route.taxType;
  console.log("Current routeTax, taxType for routeID: " + routeTax + ", " + taxType);

  console.log("\n13. TESTING: Logic for minTax/maxTax and taxType")
  route = await router.getPaymentRoute(routeID);
  routeTax = route.routeTax;
  taxType = route.taxType;
  console.log("\nTesting logic: if routeTax < minTax, then routeTax = minTax && taxType == 1")
  console.log("Current routeTax, taxType for routeID: " + routeTax + ", " + taxType);
  console.log("Adjusting to 0, routeTax should be 300 and taxType 1:")
  await router.adjustRouteTax(routeID, 0);
  route = await router.getPaymentRoute(routeID);
  routeTax = route.routeTax;
  taxType = route.taxType;
  console.log("Current routeTax, taxType for routeID: " + routeTax + ", " + taxType);

  console.log("\nTesting logic: if routeTax > maxTax, then routeTax = maxTax && taxType == 2")
  console.log("Adjusting to 20000, routeTax ?= " + maxTax + ", taxType ?= 2")
  await router.adjustRouteTax(routeID, 20000);
  route = await router.getPaymentRoute(routeID);
  routeTax = route.routeTax;
  taxType = route.taxType;
  console.log("Current routeTax, taxType for routeID: " + routeTax + ", " + taxType);

  console.log("\n14. TESTING: adjustTaxBounds(), getTaxBounds");
  let taxBounds = await router.getTaxBounds();
  console.log("Current tax bounds = " + taxBounds);
  console.log("Make sure all routes adjust appropriately upon first transfer");
  console.log("Adjusting, desired values: minTax = 100, maxTax = 2500");
  minTax = 100;
  maxTax = 2500;
  console.log("Estimating gas cost: " + await router.adjustTaxBounds.estimateGas(minTax, maxTax, {from: devWallet}));
  await router.adjustTaxBounds(minTax, maxTax, {from: devWallet});
  taxBounds = await router.getTaxBounds();
  console.log("Done: minTax = " + taxBounds[0] + " maxTax = " + taxBounds[1]);
  console.log("Send a payment down the push router for routeID, routeID2, and routeID3");
  console.log("Estimating gas cost: " + await router.pushTokens.estimateGas(routeID, stablecoin.address, buyer, price, {from: devWallet}));
  await router.pushTokens(routeID, stablecoin.address, buyer, price, {from: devWallet});
  console.log("Estimating gas cost: " + await router.pushTokens.estimateGas(routeID2, stablecoin.address, buyer, price2, {from: devWallet}));
  await router.pushTokens(routeID2, stablecoin.address, buyer, price2, {from: devWallet});
  console.log("Estimating gas cost: " + await router.pushTokens.estimateGas(routeID3, stablecoin.address, buyer, price3, {from: devWallet}));
  await router.pushTokens(routeID3, stablecoin.address, buyer, price3, {from: devWallet});
  console.log("Get routeTax and taxType for each routeID");
  route = await router.getPaymentRoute(routeID);
  console.log("RouteID 1 routeTax = " + route.routeTax);
  console.log("RouteID 1 taxType = " + route.taxType);
  route2 = await router.getPaymentRoute(routeID2);
  console.log("RouteID 2 routeTax = " + route2.routeTax);
  console.log("RouteID 2 taxType = " + route2.taxType);
  route3 = await router.getPaymentRoute(routeID3);
  console.log("RouteID 3 routeTax = " + route3.routeTax);
  console.log("RouteID 3 taxType = " + route3.taxType);

  //TEST GETTER FOR CREATOR ROUTES
  console.log("\n15. TESTING: getCreatorRoutes()");
  console.log("Call this for a seller's dashboard when they own multiple routes");
  console.log("Get creator's routes for devWallet")
  let creatorRoutes = await router.getCreatorRoutes(devWallet, {from: devWallet});
  console.log(creatorRoutes);
  console.log("Now build a list of route profiles from the user's collection:")
  console.log(await router.getPaymentRoute(creatorRoutes[0]));
  console.log(await router.getPaymentRoute(creatorRoutes[1]));
  console.log(await router.getPaymentRoute(creatorRoutes[2]));

  //SET TREASURY ADDRESS
  console.log("\n16. TESTING: setTreasuryAddress")
  console.log("Current treasury address: " + await router.pazariTreasury());
  console.log("Setting treasury address to " + treasury)
  await router.setTreasuryAddress(treasury);
  console.log("Current treasury address: " + await router.pazariTreasury());

  //TEST DIFFERENCE BETWEEN getPaymentRoute() and paymentRouteID()
  console.log("What is the difference between getPaymentRoute and paymentRoudID?")
  console.log("getPaymentRoute(routeID):")
  console.log(await router.getPaymentRoute(routeID));
  console.log("paymentRouteID(routeID):")
  console.log(await router.paymentRouteID(routeID));
};
