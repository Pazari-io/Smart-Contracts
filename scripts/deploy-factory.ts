import { FactoryPazariTokenMVP__factory } from "../types";
import { MacroChain } from "../utils";

const main = async () => {
  const { deploy, verifyDeployedContracts } = await MacroChain.init();
  const factory = await deploy(FactoryPazariTokenMVP__factory);
  await verifyDeployedContracts();
};

main()
  .then(() => process.exit(0))
  .catch((err: Error) => {
    console.error(err);
    process.exit(1);
  });
