import { ethers } from "hardhat";
import chai from "chai";
import { solidity } from "ethereum-waffle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
  ContractFactory1155,
  ContractFactory1155__factory,
  ERC1155PresetMinterPauser,
  ERC1155PresetMinterPauser__factory,
  IERC1155__factory,
  MarketplaceV0,
  MarketplaceV0__factory,
} from "../types";
import { MacroChain, toWei } from "../utils";

chai.use(solidity);
const { expect } = chai;

let marketplace: MarketplaceV0;
let token: ERC1155PresetMinterPauser;
let contractFactory: ContractFactory1155;
let accounts: SignerWithAddress[];
let macrochain: MacroChain;

describe("Marketplace", () => {
  before(async () => {
    macrochain = await MacroChain.init();
    accounts = macrochain.users;
  });

  before(async () => {
    const { deploy } = macrochain;
    marketplace = await deploy(MarketplaceV0__factory);
    token = await deploy(ERC1155PresetMinterPauser__factory);
    contractFactory = await deploy(ContractFactory1155__factory);
  });

  describe("test erc115 setup", () => {
    // TODO support the contract factory
    it("can create new token", async () => {
      const tx = await contractFactory.newERC1155Contract();
      const receipt = await tx.wait();

      //@ts-ignore
      const contractAddr = receipt.events?.filter((x) => x.event === "contractCreated")[0].args[1] as string;
      const token = IERC1155__factory.connect(contractAddr, accounts[0]);

      expect(contractAddr).to.not.eq(ethers.constants.AddressZero, "Contract address is not set");
      expect(await token.balanceOf(accounts[0].address, 1)).to.eq(
        0,
        "Shouldn't have any balance to start",
      );
    });

    it("can mint", async () => {
      const tokenID = 1; //tokenID and itemId are same
      const seller = accounts[0];

      //Function parameters for token.mint():
      const amountMint = 5;
      const tokenURI = "WEBSITE URL";
      const data = "0x";

      // console.log("token 1");
      // console.log(token);

      const balancePre = await token.balanceOf(accounts[0].address, 1);
      await token.mint(seller.address, tokenID, amountMint, tokenURI, data);
      const balancePost = await token.balanceOf(accounts[0].address, 1);

      expect(balancePre).to.eq(0, "Shouldn't have any balance before minting");
      expect(balancePost).to.eq(5, "Shouldn have a balance after minting");
    });
  });

  describe("test createMarketItem", () => {
    let seller: SignerWithAddress;
    before(() => {
      seller = accounts[0];
    });

    const itemID = 1;
    // const nftContract =  accounts[1];
    const tokenID = 1; //tokenID and itemId are same
    const price = toWei(1);
    const amount = 5;

    //Function parameters for token.mint():
    // const amountMint = 5;
    // const tokenURI = "WEBSITE URL";
    // const data = "0x";

    it("can create a basic item", async () => {
      const nftContract = token.address;
      await marketplace.createMarketItem(nftContract, tokenID, price, amount);
      //  initialBalance0 = await web3.eth.getBalance(accounts[0]);
      const items = await marketplace.fetchMarketItems();
      const item = items[0];

      expect(item.itemID).to.eq(itemID, "Item should be created successfully itemId");
      expect(item.nftContract).to.eq(
        nftContract,
        "Item should be created successfully nftContract",
      );
      expect(item.tokenID).to.eq(tokenID, "Item should be created successfully tokenId");
      expect(item.seller).to.eq(seller.address, "Item should be created successfully seller");
      expect(item.price).to.eq(price, "Item should be created successfully price");
      expect(item.amount).to.eq(amount, "Item should be created successfully amountSell");
    });

    it("cannot create duplicate marketplace item for same token", async () => {
      const nftContract = token.address;
      await expect(
        marketplace.createMarketItem(nftContract, tokenID, price, amount),
      ).to.be.reverted;
    });

    it("cannot create free items", async () => {
      const nftContract = token.address;
      await expect(
        marketplace.createMarketItem(nftContract, tokenID, 0, amount),
      ).to.be.reverted;
    });

    it("cannot create item for non existing token", async () => {
      const nftContract = token.address;
      await expect(
        marketplace.createMarketItem(nftContract, 123, 0, amount),
      ).to.be.reverted;
    });

    it("cannot create items when not enough tokens", async () => {
      const nftContract = token.address;
      await expect(
        marketplace.createMarketItem(nftContract, tokenID, price, amount + 1)
      ).to.be.reverted;
    });
  });

  describe("test buyMarketItem", () => {
    let seller: SignerWithAddress;
    before(() => {
      seller = accounts[0];
    });

    const itemID = 1;
    // const nftContract =  accounts[1];
    const tokenID = 1; //tokenID and itemId are same
    const price = toWei(1);
    const amountSell = 2;

    //Function parameters for token.mint():
    // const amountMint = 5;
    // const tokenURI = "WEBSITE URL";
    // const data = 0x0;

    it("can buy a basic item", async () => {
      await token.setApprovalForAll(marketplace.address, true);
      const itemsPre = await marketplace.fetchMarketItems();
      const itemPre = itemsPre[0];
      await marketplace.connect(accounts[1]).buyMarketItem(itemID, amountSell, {
        value: price.mul(amountSell)
      });
      // let nftContract = token.address;
      //  initialBalance0 = await web3.eth.getBalance(accounts[0]);
      const items = await marketplace.fetchMarketItems();
      const item = items[0];

      expect(item.itemID).to.eq( itemID, "Item should be created successfully itemId");
      expect(item.tokenID).to.eq( tokenID, "Item should be created successfully tokenId");
      expect(item.seller).to.eq(seller.address, "Item should be created successfully seller");
      expect(item.price,).to.eq(price, "Item should be created successfully price");
      expect(item.amount).to.eq(itemPre.amount.sub(amountSell), "Should have less items for sale after buying");

      const balance = await token.balanceOf(accounts[1].address, 1);
      expect(balance).to.eq(2, "Balance should equal tokens bought");
    });

    it("cannot buy more items than for sale", async () => {
      await expect(
        marketplace.connect(accounts[1]).buyMarketItem(itemID, 100, { value: price }),
      ).to.be.reverted;
    });

    it("cannot buy non-existing item", async () => {
      await expect(
        marketplace.connect(accounts[1]).buyMarketItem(123, amountSell, { value: price }),
      ).to.be.reverted;
    });

    it("cannot buy if you are the seller", async () => {
      await expect(
        marketplace.connect(accounts[0]).buyMarketItem(itemID, amountSell, {
          value: price.mul(amountSell),
        }),
      ).to.be.reverted;
    });

    it("cannot buy if insuffient funds", async () => {
      await expect(
        marketplace.connect(accounts[1]).buyMarketItem(itemID, amountSell, { value: price }),
      ).to.be.reverted;
    });

    it("can buy all items", async () => {
      const itemsPre = await marketplace.fetchMarketItems();
      const itemPre = itemsPre[0];
      await marketplace.connect(accounts[1]).buyMarketItem(itemID, itemPre.amount, {
        value: price.mul(itemPre.amount),
      });
      const items = await marketplace.fetchMarketItems();

      expect(items.length).to.eq(0, "No items fetched if sold out");

      const balance = await token.balanceOf(accounts[1].address, 1);
      const balanceSeller = await token.balanceOf(accounts[0].address, 1);
      expect(balance).to.eq(5, "Balance should equal tokens bought");
      expect(balanceSeller).to.eq(0, "Balance should equal tokens bought");
    });

    it("cannot buy when sold out", async () => {
      await expect(
        marketplace.connect(accounts[1]).buyMarketItem(itemID, 1, { value: price }),
      ).to.be.reverted;
    });
  });
});

/*
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
*/
