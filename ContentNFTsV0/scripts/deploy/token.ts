import { ERC1155PresetMinterPauser__factory } from "../../types";
import { MacroChain, verifyContract } from "../../utils";

const main = async () => {
  const { deployer } = await MacroChain.init();

  //Deploy token
  await deployer<ERC1155PresetMinterPauser__factory>("ERC1155PresetMinterPauser");
};

main()
  .then(async () => await verifyContract("ERC1155PresetMinterPauser"))
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
