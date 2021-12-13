/**
 * NOTE: for migration testing I'm indenting all operations that call contracts
 * and not indenting console.log() methods that only state what is happening
 * next. Any contract calls inside console.log() methods are indented. This
 * you can more easily see what is important and what is not.
 */

const MarketplaceV0 = artifacts.require("MarketplaceV0");
const ERC1155PresetMinterPauser = artifacts.require("ERC1155PresetMinterPauser");

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(MarketplaceV0);

  let market = await MarketplaceV0.deployed();
  let token = await ERC1155PresetMinterPauser.deployed();

  let buyer = accounts[1];

  //Function parameters for market.CreateMarketItem():
  let itemID = 1;
  let nftContract = token.address;
  let tokenID = 1; //tokenID and itemId are same
  let seller = accounts[0];
  let price = web3.utils.toWei('1');
  let amountSell = 1;

  //Function parameters for token.mint():
  let amountMint = 5;
  let tokenURI = "WEBSITE URL";
  let data = 0x0;

  //MINT TOKENS
  console.log("Running mint(seller = accounts[0], tokenID = 1, amountMint = 5, tokenURI = \"WEBSITE URL\", data = \"\")");
    await token.mint(seller, tokenID, amountMint, tokenURI, data);

  //CHECK INITIAL BALANCES
  console.log("Running token.balanceOf(accounts[0], tokenID = 1):");
    console.log(await token.balanceOf(seller, tokenID));
  console.log("Running token.balanceOf(accounts[1], tokenID = 1):");
    console.log(await token.balanceOf(buyer, tokenID));
  console.log("Check AVAX balance of accounts[0] and accounts[1]:");
    let initialBalance0 = await web3.eth.getBalance(accounts[0]);
    let initialBalance1 = await web3.eth.getBalance(accounts[1]);
  console.log("accounts[0] AVAX balance: " + initialBalance0);
  console.log("accounts[1] AVAX balance: " + initialBalance1);

  //PUT TOKEN FOR SALE
  console.log("Running createMarketItem(nftContract = token.address, itemID = 1, price = 0.1, amountSell = 1):");
    await market.createMarketItem(nftContract, itemID, price, amountSell, {from: accounts[0]});
    initialBalance0 = await web3.eth.getBalance(accounts[0]);

  //FETCH UNSOLD ITEM LIST
  console.log("Running fetchMarketItems():");
  console.log(await market.fetchMarketItems());

  //GIVE PERMISSION FOR MARKETPLACE TO HANDLE TOKENS
  //(This will not be necessary when token contract is ready)
  console.log("Running IERC1155.setApprovalForAll(market.address, true):")
    await token.setApprovalForAll(market.address, true);

  //BUY TOKEN
  console.log("Running buyMarketItem(tokenID = 1, amount = 1, {value: price}):");
    await market.buyMarketItem(itemID, amountSell, {value: price, from: accounts[1]});

  //FETCH UNSOLD ITEM LIST AGAIN, MAKE SURE IT'S EMPTY
  console.log("Running fetchMarketItems():");
    let marketItems = await market.fetchMarketItems();
    console.log("MarketItems array empty?" + marketItems.length == 0);

  //CHECK BALANCES, MAKE SURE TOKEN AND VALUE TRANSFERRED CORRECTLY
  console.log("Checking balances:");
  let finalBalance0 = await web3.eth.getBalance(accounts[0]);
  let finalBalance1 = await web3.eth.getBalance(accounts[1]);
  console.log("Balance of seller: " + finalBalance0);
  console.log("Balance of buyer: " + finalBalance1);
    let AVAXBalanceCompare0 = initialBalance0 < finalBalance0;
    let AVAXBalanceCompare1 = initialBalance1 > finalBalance1;
  console.log("Account[0] initialBalance < finalBalance: " + AVAXBalanceCompare0);
  console.log("Account[1] initialBalance > finalBalance: " + AVAXBalanceCompare1);
    let tokenBalance0 = await token.balanceOf(accounts[0], tokenID);
    let tokenBalance1 = await token.balanceOf(accounts[1], tokenID);
  console.log("Account[0] token balance: " + tokenBalance0);
  console.log("Account[1] token balance: " + tokenBalance1);

  //DO IT AGAIN, BUT THIS TIME ADD MORE TOKENS TO CREATE A BIGGER LIST
  //Make sure unsold item list updates properly when many, but not all,
  //orders are placed and filled.
/*
  //MINT MULTIPLE TOKENS
  console.log("Minting multiple tokens with IDs 2, 3, 4, 5:")
    await token.mint(seller, 2, 1, tokenURI, data);
    await token.mint(seller, 3, 10, tokenURI, data);
    await token.mint(seller, 4, 3, tokenURI, data);
    await token.mint(seller, 5, 5, tokenURI, data);

  //CREATE MULTIPLE SELL ORDERS
  console.log("Creating sell orders for tokens 2, 3, 4, and 5:")
    await market.createMarketItem(nftContract, 2, price, 1, {from: accounts[0]});
    await market.createMarketItem(nftContract, 3, price, 10, {from: accounts[0]});
    await market.createMarketItem(nftContract, 4, price, 3, {from: accounts[0]});
    await market.createMarketItem(nftContract, 5, price, 5, {from: accounts[0]});
  //FETCH UNSOLD ITEM LIST
  console.log("Fetching list of unsold market items:")
    console.log(await market.fetchMarketItems());
  //BUY MULTIPLE (BUT NOT ALL) TOKENS
  await market.buyMarketItem(2, {value: price, from: accounts[1]});
  await market.buyMarketItem(3, {value: price, from: accounts[1]});
  await market.buyMarketItem(4, {value: price, from: accounts[1]});

  //FETCH UNSOLD ITEM LIST AGAIN
*/
};
