const Marketplace = artifacts.require("Marketplace");
const ERC20 = artifacts.require("ERC20");
const ERC1155PresetMinterPauser = artifacts.require("ERC1155PresetMinterPauser");

module.exports = async function (deployer, network, accounts) {
  let buyer = accounts[0];
  let seller = accounts[1];
  let treasury = accounts[4];

  await deployer.deploy(Marketplace, treasury, [seller], 300, 10000, {
    gas: 4700000,
    gasPrice: 8000000000,
  });
  await deployer.deploy(ERC20, "TestCoin", "TST", { from: buyer });
  await deployer.deploy(ERC1155PresetMinterPauser);

  //let router = await PaymentRouter.deployed();
  let payToken = await ERC20.deployed();
  let market = await Marketplace.deployed();
  let itemToken = await ERC1155PresetMinterPauser.deployed();

  //  console.log(market);

  console.log("payToken.address = " + (await payToken.address));
  console.log("market.address = " + (await market.address));

  //Function parameters for router.openPaymentRoute()
  let recipients = [seller, accounts[2], accounts[3]];
  let commissions = [5000, 3150, 1850]; // 50%, 31.5%, 18.5%
  let routeTax = 300;

  //Function parameters for market.CreateMarketItem():
  let itemID;
  let itemID2;
  let tokenContract = itemToken.address;
  let tokenID = 1; //tokenID and itemId are same
  let tokenID2 = 2;
  let price = web3.utils.toWei("100"); // Price in stablecoins
  let price2 = web3.utils.toWei("50");
  let approveAmount = web3.utils.toWei("200"); // Amount of payment tokens to approve
  let itemLimit1 = 0; // Test out infinite itemLimit code
  let itemLimit2 = 3;
  let sellAmount1 = 5; // Amount of items to sell
  let amountBuy = 1;
  let sellAmount2 = 3;
  let amountBuy2 = 2;
  let paymentContract = payToken.address;
  let isPush = true;
  let isPull = false; // Use for isPush argument
  let routeID;

  //Function parameters for token.mint():
  let amountMint = 5;
  let tokenURI = "WEBSITE URL";
  let data = 0x0;

  //CHECK INITIAL PAYMENT TOKEN BALANCES
  console.log("Running payToken.balanceOf(buyer, seller, accounts[2], accounts[3], accounts[4]):");
  console.log(web3.utils.fromWei(await payToken.balanceOf(buyer)));
  console.log(web3.utils.fromWei(await payToken.balanceOf(seller)));
  console.log(web3.utils.fromWei(await payToken.balanceOf(accounts[2])));
  console.log(web3.utils.fromWei(await payToken.balanceOf(accounts[3])));
  console.log(web3.utils.fromWei(await payToken.balanceOf(accounts[4])));

  //MINT ITEM TOKENS
  console.log("Minting item tokens");
  await itemToken.mint(seller, tokenID, amountMint, tokenURI, data);
  await itemToken.mint(seller, tokenID2, amountMint, tokenURI, data);

  //CHECK INITIAL ITEM TOKEN BALANCES
  console.log("Fetching itemToken balances for buyer and seller, tokenID = 1:");
  console.log(await itemToken.balanceOf(buyer, tokenID));
  console.log(await itemToken.balanceOf(seller, tokenID));
  console.log("Fetching itemToken balances for buyer and seller, tokenID = 2:");
  console.log(await itemToken.balanceOf(buyer, tokenID2));
  console.log(await itemToken.balanceOf(seller, tokenID2));

  //CREATE A NEW PAYMENT ROUTE
  console.log("Creating new payment route");
  routeID = await market.getPaymentRouteID(seller, recipients, commissions);
  await market.openPaymentRoute(recipients, commissions, routeTax, { from: seller });
  console.log("routeID: " + routeID);

  //APPROVE MARKETPLACE TO HANDLE TOKENS
  console.log("Running IERC1155.setApprovalForAll():");
  await itemToken.setApprovalForAll(market.address, true, { from: seller });
  console.log("Running IERC20.approve():");
  await payToken.approve(market.address, approveAmount, { from: buyer });

  //PUT ITEM FOR SALE
  console.log("Running createMarketItem() for itemID 1:");
  await market.createMarketItem(
    tokenContract,
    seller,
    tokenID,
    sellAmount1,
    price,
    paymentContract,
    isPull,
    true,
    routeID,
    itemLimit1,
    false,
    { from: seller },
  );
  itemID = await market.getLastItemID();
  console.log("itemID: " + (await itemID));
  //console.log(await itemToken.balanceOf(market.address, tokenID));
  console.log(
    "itemID " + (await itemID) + " has " + (await itemToken.balanceOf(market.address, tokenID)) + " units available",
  );
  console.log("Running createMarketItem() for itemID 2:");
  await market.createMarketItem(
    tokenContract,
    seller,
    tokenID2,
    sellAmount2,
    price2,
    paymentContract,
    isPush,
    true,
    routeID,
    itemLimit2,
    false,
    { from: seller },
  );
  itemID2 = await market.getLastItemID();
  console.log("itemID2: " + (await itemID2));
  console.log(
    "itemID " + itemID2 + " has " + (await itemToken.balanceOf(market.address, tokenID2)) + " units available",
  );

  //FETCH UNSOLD ITEM LIST
  console.log("Running getItemsForSale():");
  let marketItems = await market.getItemsForSale();
  console.log(marketItems[0]);
  console.log(marketItems[1]);

  //BUY TOKEN
  // let allowance = payToken.allowance(buyer, market.address);
  // console.log("Checking payToken allowance: " + web3.utils.fromWei(await allowance));
  // console.log("Running buyMarketItem() for itemID 1:");
  // await market.buyMarketItem(itemID, amountBuy, { from: buyer });
  // console.log("Running buyMarketItem() for itemID 2:");
  // await market.buyMarketItem(itemID2, amountBuy2, { from: buyer });

  //FETCH UNSOLD ITEM LIST AGAIN, MAKE SURE IT CLEARS CORRECTLY
  console.log("Running getItemsForSale():");
  marketItems = await market.getItemsForSale();
  console.log(marketItems[0]);
  console.log(marketItems[1]);

  //CHECK BALANCES, MAKE SURE TOKEN AND VALUE ROUTED CORRECTLY
  console.log("Checking itemToken balances for tokenID 1: (buyer: accounts[0], seller: accounts[1])");
  console.log(await itemToken.balanceOf(accounts[0], tokenID).then((bn) => bn.toNumber()));
  console.log(await itemToken.balanceOf(accounts[1], tokenID).then((bn) => bn.toNumber()));
  console.log(await itemToken.balanceOf(accounts[2], tokenID).then((bn) => bn.toNumber()));
  console.log(await itemToken.balanceOf(accounts[3], tokenID).then((bn) => bn.toNumber()));
  console.log(await itemToken.balanceOf(accounts[4], tokenID).then((bn) => bn.toNumber()));
  console.log("Checking itemToken balances for tokenID 2: (buyer: accounts[0], seller: accounts[1])");
  console.log(await itemToken.balanceOf(accounts[0], tokenID2).then((bn) => bn.toNumber()));
  console.log(await itemToken.balanceOf(accounts[1], tokenID2).then((bn) => bn.toNumber()));
  console.log(await itemToken.balanceOf(accounts[2], tokenID2).then((bn) => bn.toNumber()));
  console.log(await itemToken.balanceOf(accounts[3], tokenID2).then((bn) => bn.toNumber()));
  console.log(await itemToken.balanceOf(accounts[4], tokenID2).then((bn) => bn.toNumber()));
  console.log("Checking payToken balances: (buyer: accounts[0], seller: accounts[1])");
  console.log(web3.utils.fromWei(await payToken.balanceOf(accounts[0])));
  console.log(web3.utils.fromWei(await payToken.balanceOf(accounts[1])));
  console.log(web3.utils.fromWei(await payToken.balanceOf(accounts[2])));
  console.log(web3.utils.fromWei(await payToken.balanceOf(accounts[3])));
  console.log(web3.utils.fromWei(await payToken.balanceOf(accounts[4])));
  console.log("Pulling tokens from pullTokens():");
  // await market.pullTokens(routeID, payToken.address, { from: recipients[0] });
  // await market.pullTokens(routeID, payToken.address, { from: recipients[1] });
  // await market.pullTokens(routeID, payToken.address, { from: recipients[2] });
  // console.log("Checking payToken balances: (buyer: accounts[0], seller: accounts[1])");
  // console.log(web3.utils.fromWei(await payToken.balanceOf(accounts[0])));
  // console.log(web3.utils.fromWei(await payToken.balanceOf(accounts[1])));
  // console.log(web3.utils.fromWei(await payToken.balanceOf(accounts[2])));
  // console.log(web3.utils.fromWei(await payToken.balanceOf(accounts[3])));
  // console.log(web3.utils.fromWei(await payToken.balanceOf(accounts[4])));

  /*

  //CHECK BALANCES, MAKE SURE TOKEN AND VALUE TRANSFERRED CORRECTLY
console.log("Running token.balanceOf(accounts[0], accounts[1], accounts[2], accounts[3], accounts[4]):");
  console.log(await token.balanceOf(accounts[0]));
  console.log(await token.balanceOf(accounts[1]));
  console.log(await token.balanceOf(accounts[2]));
  console.log(await token.balanceOf(accounts[3]));
  console.log(await token.balanceOf(accounts[4]));
*/
};
