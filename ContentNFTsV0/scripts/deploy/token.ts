import { ERC1155PresetMinterPauser__factory } from "../../types";
import { MacroChain, verifyContract } from "../../utils";

const main = async () => {
  const { deploy } = await MacroChain.init();

  //Deploy token
  await deploy(ERC1155PresetMinterPauser__factory);
};

main()
  .then(async () => await verifyContract("ERC1155PresetMinterPauser"))
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
