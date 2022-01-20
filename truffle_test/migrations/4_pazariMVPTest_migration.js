/**
 * These migration tests are for the PazariMVP helper contract.
 */
const Marketplace = artifacts.require("Marketplace");
const PaymentRouter = artifacts.require("PaymentRouter");
// Mock stablecoin
const ERC20PresetMinterPauser = artifacts.require("ERC20PresetMinterPauser");
const IPazariTokenMVP = artifacts.require("IPazariTokenMVP");
const PazariTokenMVP = artifacts.require("PazariTokenMVP");
const PazariMVP = artifacts.require("PazariMVP");
const FactoryPazariTokenMVP = artifacts.require("FactoryPazariTokenMVP");
// Someone's lost NFT: Tests recoverNFT()
const ERC1155PresetMinterPauser = artifacts.require("ERC1155PresetMinterPauser");

module.exports = async function (deployer, network, accounts) {
  let buyer = accounts[0];
  let seller = accounts[1];
  let seller2 = accounts[2];
  let pazariDev = accounts[4];
  let treasury = accounts[5];
  let nftOwner = accounts[8];

  //DEPLOY STABLECOIN
  console.log("Deploying ERC20 mock-stablecoin, minting $200 for buyer");
  await deployer.deploy(ERC20PresetMinterPauser, "Magic Internet Money", "MIM", { from: buyer });
  let stablecoin = await ERC20PresetMinterPauser.deployed();
  await stablecoin.mint(buyer, web3.utils.toWei("200"));

  //DEPLOY PAYMENT ROUTER
  console.log("Deploying PaymentRouter");
  await deployer.deploy(PaymentRouter, treasury, [pazariDev], 300, 10000, { from: pazariDev });
  let router = await PaymentRouter.deployed();

  //DEPLOY MARKETPLACE
  console.log("Deploying Marketplace");
  await deployer.deploy(Marketplace, router.address, [pazariDev], {
    gas: 6721975,
    gasPrice: 8000000000,
    from: pazariDev,
  });
  let market = await Marketplace.deployed();

  //DEPLOY CONTRACT FACTORY
  await deployer.deploy(FactoryPazariTokenMVP, { from: pazariDev });
  let factory = await FactoryPazariTokenMVP.deployed();

  //DEPLOY PAZARI MVP CONTRACT
  // pazariDev is an array of all Pazari devs who can access admin functions
  await deployer.deploy(PazariMVP, factory.address, market.address, router.address, stablecoin.address, [pazariDev], {
    from: pazariDev,
  });
  let pazariMVP = await PazariMVP.deployed();
  console.log("Marketplace isAdmin[pazariDev]: " + (await market.isAdmin(pazariDev, { from: pazariDev })));
  console.log("PaymentRouter isAdmin[pazariDev]: " + (await router.isAdmin(pazariDev, { from: pazariDev })));
  console.log("Adding PazariMVP as admin for Marketplace");
  let memo = "John Doe - Web Designer";

  await market.addAdmin(pazariMVP.address, memo, { from: pazariDev });
  console.log("Adding PazariMVP as admin for PaymentRouter");
  await router.addAdmin(pazariMVP.address, memo, { from: pazariDev });
  console.log("Adding PazariMVP as admin for PazariTokenMVP");

  // MarketItem #1
  let uri1 = "TOKEN'S_URI_GOES_HERE";
  let amount1 = 50;
  let price1 = web3.utils.toWei("4.99");

  // Log all contract addresses, make sure they exist
  console.log("\nLogging all contract addresses:");
  console.log("stablecoin.address = " + (await stablecoin.address));
  console.log("router.address = " + (await router.address));
  console.log("market.address = " + (await market.address));
  console.log("factory.address = " + (await factory.address));
  console.log("pazariMVP.address = " + (await pazariMVP.address));
  console.log("accounts[0] = " + accounts[0]);
  console.log("accounts[1] = " + accounts[1]);
  console.log("accounts[2] = " + accounts[2]);
  console.log("accounts[3] = " + accounts[3]);
  console.log("accounts[4] = " + accounts[4]);
  console.log("accounts[5] = " + accounts[5]);
  console.log("accounts[6] = " + accounts[6]);
  console.log("accounts[7] = " + accounts[7]);
  console.log("accounts[8] = " + accounts[8]);
  console.log("accounts[9] = " + accounts[9]);

  // Test AccessControl functions
  console.log("\n0. Testing AccessControl functions");
  let message = "John Doe, April 1st 1950";

  console.log("isAdmin[pazariDev]: " + (await pazariMVP.isAdmin(pazariDev)));
  console.log("isAdmin[seller]: " + (await pazariMVP.isAdmin(seller)));
  console.log("_msgSender(): " + (await pazariMVP._msgSender({ from: pazariDev })));
  console.log("Adding seller as admin");
  console.log("Estimating gas: " + (await pazariMVP.addAdmin.estimateGas(seller, message, { from: pazariDev })));
  await pazariMVP.addAdmin(seller, message, { from: pazariDev });
  console.log("isAdmin[seller]: " + (await pazariMVP.isAdmin(seller)));

  message = "Elizabeth Rondopololopiatacamarina is a Communist spy!";
  console.log("isAdmin[seller]: " + (await pazariMVP.isAdmin(seller)));
  console.log("Removing seller as admin");
  console.log("Estimating gas: " + (await pazariMVP.removeAdmin.estimateGas(seller, message, { from: pazariDev })));
  await pazariMVP.removeAdmin(seller, message, { from: pazariDev });
  console.log("isAdmin[seller]: " + (await pazariMVP.isAdmin(seller)));
  /*
  // Test createNewUserAndListing()
  console.log("\n1. RUNNING createUserProfile(seller):");
  console.log("Inputs: " + uri1 + ", " + amount1 + ", " + price1);
  console.log("Create an item with amount " + amount1 + " and price $" + price1);
  console.log(
    "Estimating gas: " + (await pazariMVP.createUserProfile.estimateGas(uri1, amount1, price1, { from: seller })),
  );
  await pazariMVP.createUserProfile(uri1, amount1, price1, { from: seller });
*/
  console.log("\n1. RUNNING newTokenListing(seller):");
  console.log("Inputs: " + uri1 + ", " + amount1 + ", " + price1);
  console.log("Create an item with amount " + amount1 + " and price $" + price1);
  console.log(
    "Estimating gas: " + (await pazariMVP.newTokenListing.estimateGas(uri1, amount1, price1, { from: seller })),
  );
  await pazariMVP.newTokenListing(uri1, amount1, price1, { from: seller });
  // Test getUserProfile()
  // Test ability to return itemIDs array from returned UserProfile
  console.log("\n2. RUNNING getUserProfile(seller)");
  console.log("Let's build a mini-shop with seller's items");
  let userProfileGetter = await pazariMVP.getUserProfile(seller);
  tokenAddress = userProfileGetter.tokenContract;
  console.log("User profile:");
  console.log(userProfileGetter);
  console.log("Storing itemIDs");
  let itemIDs = userProfileGetter.itemIDs;
  console.log("itemIDs: " + itemIDs);

  // Test getMarketItems() using itemIDs from test #2
  console.log("\n3. RUNNING market.getMarketItems(itemIDs)");
  console.log("itemIDs: " + itemIDs);
  console.log("Running getMarketItems(itemIDs)");
  console.log(await market.getMarketItems(itemIDs));

  // Test newTokenListing() for same seller as test #1
  console.log("\n4. RUNNING newTokenListing(seller):");
  var uri2 = "TOKEN_URI_2_GOES_HERE";
  var amount2 = 20;
  var price2 = web3.utils.toWei("9.99");
  console.log("Create an item with amount " + amount2 + " and price $" + price2);
  console.log("Inputs: " + uri2 + ", " + amount2 + ", " + price2);
  console.log(
    "Estimating gas: " + (await pazariMVP.newTokenListing.estimateGas(uri2, amount2, price2, { from: seller })),
  );
  await pazariMVP.newTokenListing(uri2, amount2, price2, { from: seller });

  // Run getUserProfile() again, make sure itemIDs has new itemID from test #4
  console.log("\n5. RUNNING getUserProfile(seller):");
  userProfileGetter = await pazariMVP.getUserProfile(seller);
  console.log(userProfileGetter);
  itemIDs = userProfileGetter.itemIDs;
  console.log("itemIDs: " + itemIDs);

  // Run getMarketItems(itemIDs), see that item listing updated correctly
  console.log("\n6. RUNNING market.getMarketItems(itemIDs)");
  console.log(await market.getMarketItems(itemIDs));

  // Test getItemIDsForSale()
  console.log("\n7. RUNNING market.getItemIDsForSale():");
  var forSaleItemIDs = await market.getItemIDsForSale();
  console.log("forSaleItemIDs:" + forSaleItemIDs);

  /*
  // Test if manually entering an array of [1] works
  console.log("\n8. RUNNING market.getMarketItems([1]):");
  console.log(await market.getMarketItems([1]));
  */

  // Run getMarketItems() using returned value from test #7
  console.log("\n9. RUNNING market.getMarketItems(forSaleItemIDs):");
  console.log("forSaleItemIDs: " + forSaleItemIDs);
  console.log(await market.getMarketItems(forSaleItemIDs));

  // Run newUser() for seller2
  console.log("\n10. RUNNING pazariMVP.newTokenListing(seller2)");
  var uri3 = "SOME_URI_HERE";
  var amount3 = 30;
  var price3 = web3.utils.toWei("14.99");
  console.log("Create an item with amount " + amount3 + " and price $" + price3);
  console.log("Inputs: " + uri3 + ", " + amount3 + ", " + price3);
  console.log(
    "Estimating gas: " + (await pazariMVP.newTokenListing.estimateGas(uri1, amount1, price1, { from: seller2 })),
  );
  await pazariMVP.newTokenListing(uri1, amount1, price1, { from: seller2 });

  // Run newTokenListing(seller) (not seller2)
  // Need to check that tokenIDs and itemIDs increment independently and correctly
  console.log("\n11. RUNNING pazariMVP.newTokenListing(seller)");
  var uri4 = "SOME_URI_HERE";
  var amount4 = 10;
  var price4 = web3.utils.toWei("99.99");
  console.log("Create an item with amount " + amount4 + " and price $" + price4);
  console.log("Inputs: " + uri4 + ", " + amount4 + ", " + price4);
  console.log(
    "Estimating gas: " + (await pazariMVP.newTokenListing.estimateGas(uri4, amount4, price4, { from: seller })),
  );
  await pazariMVP.newTokenListing(uri4, amount4, price4, { from: seller });

  // Run getItemIDsForSale(), store as forSaleItemIDs
  console.log("\n12. RUNNING market.getItemIDsForSale(), storing as forSaleItemIDs:");
  forSaleItemIDs = await market.getItemIDsForSale();
  console.log("forSaleItemIDs: " + forSaleItemIDs);

  // Run getMarketItems(forSaleItemIDs), and look at the tokenIDs and itemIDs from different sellers
  console.log("\n13. RUNNING market.getMarketItems(forSaleItemIDs)");
  console.log(await market.getMarketItems(forSaleItemIDs));

  /*
  // Run getUserProfile(seller), then run getMarketItems(itemIDs);
  console.log("\n14. RUNNING getUserProfile(seller), market.getMarketItems(itemIDs)");
  console.log("Use this for assembling a store of items by a particular address");
  userProfileGetter = await pazariMVP.getUserProfile(seller);
  console.log("User profile:");
  console.log(userProfileGetter);
  itemIDs = userProfileGetter.itemIDs;
  console.log("itemIDs: " + itemIDs);
  console.log("Running getMarketItems(itemIDs)");
  console.log(await market.getMarketItems(itemIDs));
  */

  // Create a store from seller2's itemIDs
  console.log("\n15. RUNNING getUserProfile(seller2), market.getMarketItems(itemIDs2)");
  console.log("Return an array of all itemIDs made by this seller");
  userProfileGetter = await pazariMVP.getUserProfile(seller2);
  console.log("User profile:");
  console.log(userProfileGetter);
  itemIDs2 = userProfileGetter.itemIDs;
  console.log("itemIDs: " + itemIDs2);
  console.log("Running getMarketItems(itemIDs)");
  console.log(await market.getMarketItems(itemIDs2));

  // Test recoverNFT()
  // Deploy ERC1155PresetMinterPauser from the NFT owner, mint a token, then transfer to Pazari
  console.log("\n16. RUNNING recoverNFT():");
  console.log("Create + mint NFT, transfer to contract, then use admin address to send back");
  let nftID = 1;
  let nftAmount = 1;
  let nftURI = "SOME_NFT_URI";
  let nftData = "0x0";

  // ERC1155PresetMinterPauser functions
  console.log("\nDeploying ERC1155 token contract from nftOwner");
  await deployer.deploy(ERC1155PresetMinterPauser, { from: nftOwner });
  let someToken = await ERC1155PresetMinterPauser.deployed();
  console.log("someToken.address: " + someToken.address);
  console.log("Minting NFT that will be transferred to PazariMVP");
  await someToken.mint(nftOwner, nftID, nftAmount, nftURI, nftData, { from: nftOwner });
  console.log("Checking balanceOf nftOwner: " + (await someToken.balanceOf(nftOwner, 1)));
  console.log("Transferring NFT to PazariMVP contract");
  await someToken.safeTransferFrom(nftOwner, pazariMVP.address, nftID, nftAmount, nftData, { from: nftOwner });
  console.log("Checking balanceOf PazariMVP: " + (await someToken.balanceOf(pazariMVP.address, 1)));
  console.log("Checking balanceOf nftOwner: " + (await someToken.balanceOf(nftOwner, 1)));
  console.log("User contacts Pazari about missing NFT");

  console.log("\nCalling recoverNFT({from: pazariDev}):");
  await pazariMVP.recoverNFT(someToken.address, 1, 1, nftOwner, { from: pazariDev });
  console.log("Checking balanceOf PazariMVP: " + (await someToken.balanceOf(pazariMVP.address, 1)));
  console.log("Checking balanceOf nftOwner: " + (await someToken.balanceOf(nftOwner, 1)));

  console.log("\nTESTING COMPLETE");
};
