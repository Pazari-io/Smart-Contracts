const Marketplace = artifacts.require("./MarketplaceV0.sol");
const ContractFactory = artifacts.require("./ContractFactory1155.sol");
const ERC1155Token = artifacts.require("./ERC1155PresetMinterPauser.sol");
const { assert } = require("chai");
const truffleAssert = require("truffle-assertions");

contract("Marketplace", (accounts) => {
  let marketplace;
  let token;

  before(async () => {
    marketplace = await Marketplace.deployed();
    token = await ERC1155Token.deployed();
    // contractFactory = await ContractFactory.deployed();
  });

  describe("test erc115 setup", async () => {
    //TODO support the contract factory
    //    it("can create new token", async () => {
    //      let contract = await contractFactory.newERC1155Contract({from: accounts[0]});
    //      token = IERC1155(contract);
    //      assert.notEqual(contract, '0x0000000000000000000000000000000000000000' , "Contract address is not set");
    //      assert.equal(token.balanceOf(accounts[0], 1, {from: accounts[0]}), 0, "Shouldn't have any balance to start");
    //    });

    it("can mint", async () => {
      let tokenID = 1; //tokenID and itemId are same
      let seller = accounts[0];

      //Function parameters for token.mint():
      let amountMint = 5;
      let tokenURI = "WEBSITE URL";
      let data = 0x0;

      console.log("token 1");
      console.log(token);
      let balancePre = await token.balanceOf(accounts[0], 1, { from: accounts[0] });
      await token.mint(seller, tokenID, amountMint, tokenURI, data, { from: accounts[0] });
      let balancePost = await token.balanceOf(accounts[0], 1, { from: accounts[0] });
      assert.equal(balancePre, 0, "Shouldn't have any balance before minting");
      assert.equal(balancePost, 5, "Shouldn have a balance after minting");
    });
  });

  describe("test createMarketItem", async () => {
    let itemID = 1;
    // let nftContract =  accounts[1];
    let tokenID = 1; //tokenID and itemId are same
    let seller = accounts[0];
    let price = web3.utils.toWei("1");
    let amount = 5;

    //Function parameters for token.mint():
    let amountMint = 5;
    let tokenURI = "WEBSITE URL";
    let data = 0x0;

    it("can create a basic item", async () => {
      let nftContract = token.address;
      await marketplace.createMarketItem(nftContract, tokenID, price, amount, {
        from: accounts[0],
      });
      //  initialBalance0 = await web3.eth.getBalance(accounts[0]);
      let items = await marketplace.fetchMarketItems({ from: accounts[0] });
      let item = items[0];

      assert.equal(item.itemID, itemID, "Item should be created successfully itemId");
      assert.equal(
        item.nftContract,
        nftContract,
        "Item should be created successfully nftContract",
      );
      assert.equal(item.tokenID, tokenID, "Item should be created successfully tokenId");
      assert.equal(item.seller, seller, "Item should be created successfully seller");
      assert.equal(item.price, price, "Item should be created successfully price");
      assert.equal(item.amount, amount, "Item should be created successfully amountSell");
    });

    it("cannot create duplicate marketplace item for same token", async () => {
      let nftContract = token.address;
      await truffleAssert.reverts(
        marketplace.createMarketItem(nftContract, tokenID, price, amount, { from: accounts[0] }),
      );
    });

    it("cannot create free items", async () => {
      let nftContract = token.address;
      await truffleAssert.reverts(
        marketplace.createMarketItem(nftContract, tokenID, 0, amount, { from: accounts[0] }),
      );
    });

    it("cannot create item for non existing token", async () => {
      let nftContract = token.address;
      await truffleAssert.reverts(
        marketplace.createMarketItem(nftContract, 123, 0, amount, { from: accounts[0] }),
      );
    });

    it("cannot create items when not enough tokens", async () => {
      let nftContract = token.address;
      await truffleAssert.reverts(
        marketplace.createMarketItem(nftContract, tokenID, price, amount + 1, {
          from: accounts[0],
        }),
      );
    });
  });

  describe("test buyMarketItem", async () => {
    let itemID = 1;
    // let nftContract =  accounts[1];
    let tokenID = 1; //tokenID and itemId are same
    let seller = accounts[0];
    let price = web3.utils.toWei("1");
    let amountSell = 2;

    //Function parameters for token.mint():
    let amountMint = 5;
    let tokenURI = "WEBSITE URL";
    let data = 0x0;

    it("can buy a basic item", async () => {
      await token.setApprovalForAll(marketplace.address, true);
      let itemsPre = await marketplace.fetchMarketItems({ from: accounts[0] });
      let itemPre = itemsPre[0];
      await marketplace.buyMarketItem(itemID, amountSell, {
        value: price * amountSell,
        from: accounts[1],
      });
      // let nftContract = token.address;
      //  initialBalance0 = await web3.eth.getBalance(accounts[0]);
      let items = await marketplace.fetchMarketItems({ from: accounts[0] });
      let item = items[0];

      assert.equal(item.itemID, itemID, "Item should be created successfully itemId");
      assert.equal(item.tokenID, tokenID, "Item should be created successfully tokenId");
      assert.equal(item.seller, seller, "Item should be created successfully seller");
      assert.equal(item.price, price, "Item should be created successfully price");
      assert.equal(
        item.amount,
        itemPre.amount - amountSell,
        "Should have less items for sale after buying",
      );

      let balance = await token.balanceOf(accounts[1], 1, { from: accounts[1] });
      assert.equal(balance, 2, "Balance should equal tokens bought");
    });

    it("cannot buy more items than for sale", async () => {
      await truffleAssert.reverts(
        marketplace.buyMarketItem(itemID, 100, { value: price, from: accounts[1] }),
      );
    });

    it("cannot buy non-existing item", async () => {
      await truffleAssert.reverts(
        marketplace.buyMarketItem(123, amountSell, { value: price, from: accounts[1] }),
      );
    });

    it("cannot buy if you are the seller", async () => {
      await truffleAssert.reverts(
        marketplace.buyMarketItem(itemID, amountSell, {
          value: price * amountSell,
          from: accounts[0],
        }),
      );
    });

    it("cannot buy if insuffient funds", async () => {
      await truffleAssert.reverts(
        marketplace.buyMarketItem(itemID, amountSell, { value: price, from: accounts[1] }),
      );
    });

    it("can buy all items", async () => {
      let itemsPre = await marketplace.fetchMarketItems({ from: accounts[0] });
      let itemPre = itemsPre[0];
      await marketplace.buyMarketItem(itemID, itemPre.amount, {
        value: price * itemPre.amount,
        from: accounts[1],
      });
      let items = await marketplace.fetchMarketItems({ from: accounts[0] });

      assert.equal(items.length, 0, "No items fetched if sold out");

      let balance = await token.balanceOf(accounts[1], 1, { from: accounts[1] });
      let balanceSeller = await token.balanceOf(accounts[0], 1, { from: accounts[1] });
      assert.equal(balance, 5, "Balance should equal tokens bought");
      assert.equal(balanceSeller, 0, "Balance should equal tokens bought");
    });

    it("cannot buy when sold out", async () => {
      await truffleAssert.reverts(
        marketplace.buyMarketItem(itemID, 1, { value: price, from: accounts[1] }),
      );
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
