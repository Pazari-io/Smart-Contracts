import {
  ContractFactory1155__factory,
  ERC1155PresetMinterPauser__factory,
  MarketplaceV0__factory,
} from "../../types";
import { MacroChain, verifyContract } from "../../utils";

const main = async () => {
  const { deployer, users } = await MacroChain.init();

  //Deploy marketplace?
  let market = await deployer<MarketplaceV0__factory>("MarketplaceV0__factory");
  const factory = await deployer<ContractFactory1155__factory>("ContractFactory1155");
  const token = await deployer<ERC1155PresetMinterPauser__factory>("ERC1155PresetMinterPauser");

  //DO IT AGAIN, BUT THIS TIME ADD MORE TOKENS TO CREATE A BIGGER LIST
  //Make sure unsold item list updates properly when many, but not all,
  //orders are placed and filled.

  //MINT MULTIPLE TOKENS
  console.log("Minting multiple tokens with IDs 2, 3, 4, 5:");
  const seller = "";
  const tokenURI = ""
  const data = "0x";
  await token.mint(seller, 2, 1, tokenURI, data);
  await token.mint(seller, 3, 10, tokenURI, data);
  await token.mint(seller, 4, 3, tokenURI, data);
  await token.mint(seller, 5, 5, tokenURI, data);

  //CREATE MULTIPLE SELL ORDERS
  console.log("Creating sell orders for tokens 2, 3, 4, and 5:");
  const nftContract = "";
  const price = 10000000;
  await market.createMarketItem(nftContract, 2, price, 1);
  await market.createMarketItem(nftContract, 3, price, 10);
  await market.createMarketItem(nftContract, 4, price, 3);
  await market.createMarketItem(nftContract, 5, price, 5);

  //FETCH UNSOLD ITEM LIST
  console.log("Fetching list of unsold market items:");
  console.log(await market.fetchMarketItems());
  //BUY MULTIPLE (BUT NOT ALL) TOKENS
  const amount = 1;
  await market.connect(users[1]).buyMarketItem(2, amount,{ value: price });
  await market.connect(users[1]).buyMarketItem(3, amount,{ value: price });
  await market.connect(users[1]).buyMarketItem(4, amount,{ value: price });

  //FETCH UNSOLD ITEM LIST AGAIN
};

main()
  .then(
    async () =>
      await verifyContract(
        "MarketplaceV0__factory",
        "ContractFactory1155",
        "ERC1155PresetMinterPauser",
      ),
  )
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
