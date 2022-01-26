import {
  Marketplace__factory,
  PaymentRouter__factory,
  PazariMVP__factory,
  FactoryPazariTokenMVP__factory,
  MIM__factory,
} from "../types";
import { MacroChain } from "../utils";

const main = async () => {
  const { users, deploy, verifyDeployedContracts } = await MacroChain.init();

  //Setup accounts
  const deployer = users[0];
  const cryptoPhonix = users[1];
  const rego350 = users[2];
  const treasury = users[9];

  //Deploy PaymentRouter
  const admins = [deployer.address, cryptoPhonix.address, rego350.address];
  const minTax = 300;
  const maxTax = 10000;
  const pr = await deploy(PaymentRouter__factory, {
    args: [treasury.address, admins, minTax, maxTax],
  });

  //Deploy Marketplace
  const mp = await deploy(Marketplace__factory, {
    args: [pr.address, admins],
  });

  //Deploy Mock Stablecoin
  const mim = await deploy(MIM__factory);

  //Deploy pazari token factory contract
  const factory = await deploy(FactoryPazariTokenMVP__factory);

  //Deploy pazari mvp
  const pazariMvp = await deploy(PazariMVP__factory, {
    args: [factory.address, mp.address, pr.address, mim.address, admins],
  });

  await verifyDeployedContracts();

  //Add pazari mvp as admin for mp and pr
  const memo = "Added pazari mvp as admin";
  await mp.connect(cryptoPhonix).addAdmin(pazariMvp.address, memo);
  await pr.connect(cryptoPhonix).addAdmin(pazariMvp.address, memo);
};

main()
  .then(() => process.exit(0))
  .catch((err: Error) => {
    console.error(err);
    process.exit(1);
  });
