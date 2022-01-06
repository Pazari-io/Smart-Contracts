import {
  ERC20PresetMinterPauser__factory,
  Marketplace__factory,
  PaymentRouter__factory,
  PazariTokenMVP__factory,
} from "../types";
import { MacroChain } from "../utils";

const main = async () => {
  const { users, deploy, verifyDeployedContracts } = await MacroChain.init();

  //Setup accounts
  const deployer = users[0];
  const treasury = users[1];
  const seller = users[2];

  //Deploy PaymentRouter
  const devs = [deployer.address];
  const minTax = 300;
  const maxTax = 10000;
  const pr = await deploy(PaymentRouter__factory, {
    args: [treasury.address, devs, minTax, maxTax],
  });

  //Deploy Marketplace
  const mp = await deploy(Marketplace__factory, {
    args: [pr.address],
  });

  //Deploy Mock Stablecoin
  const mim = await deploy(ERC20PresetMinterPauser__factory, {
    args: ["Magic Internet Money", "MIM"],
  });

  //Deploy Pazari Token (ERC1155 like token)
  const contractOwners = [seller.address, pr.address, mp.address];
  const token = await deploy(PazariTokenMVP__factory, {
    args: [contractOwners],
  });

  await verifyDeployedContracts();
};

main()
  .then(() => process.exit(0))
  .catch((err: Error) => {
    console.error(err);
    process.exit(1);
  });
