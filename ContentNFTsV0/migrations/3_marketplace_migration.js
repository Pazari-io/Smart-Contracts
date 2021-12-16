/**
 * NOTE: for migration testing I'm indenting all operations that call contracts
 * and not indenting console.log() methods that only state what is happening
 * next. Any contract calls inside console.log() methods are indented. This
 * you can more easily see what is important and what is not.
 */

const MarketplaceV0 = artifacts.require("MarketplaceV0");
const ContractFactory1155 = artifacts.require("ContractFactory1155");
const ERC1155PresetMinterPauser = artifacts.require("ERC1155PresetMinterPauser");

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(MarketplaceV0);
  await deployer.deploy(ContractFactory1155);
  await deployer.deploy(ERC1155PresetMinterPauser);

  // let market = await MarketplaceV0.deployed();
  // let token = await ERC1155PresetMinterPauser.deployed();

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
