import hre, { ethers } from "hardhat";
import editJsonFile from "edit-json-file";
import { ContractFactory } from "@ethersproject/contracts";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Time } from ".";
import fs from "fs";

type DeployParam<T extends ContractFactory> = Parameters<InstanceType<{ new (): T }>["deploy"]>;
type ContractInstance<T extends ContractFactory> = ReturnType<InstanceType<{ new (): T }>["attach"]>;

interface ContractLog {
  address: string;
  txHash: string;
  args: any[]; //eslint-disable-line @typescript-eslint/no-explicit-any
}

export class MacroChain {
  public deployer: SignerWithAddress;
  public users: SignerWithAddress[];
  private deployedContracts: string[];
  private globalLog: boolean | undefined;

  constructor(signer: SignerWithAddress | SignerWithAddress[], log?: boolean) {
    if (Array.isArray(signer)) {
      this.users = signer;
    } else {
      this.users = [signer];
    }
    this.deployer = this.users[0];
    this.deployedContracts = [];
    this.globalLog = log;
  }

  static init = async (
    option: {
      log?: boolean;
    } = {
      log: undefined,
    },
  ): Promise<MacroChain> => {
    const signers = await ethers.getSigners();
    const macrochain = new MacroChain(signers, option.log);
    return macrochain;
  };

  static deploy = async <T extends ContractFactory>(
    contractFactory: new () => T,
    option: {
      from?: SignerWithAddress;
      args?: DeployParam<T>;
      log?: boolean;
    } = {
      log: undefined,
    },
  ): Promise<ContractInstance<T>> => {
    let macrochain: MacroChain;
    if (option.from) {
      macrochain = new MacroChain(option.from);
    } else {
      macrochain = await this.init({ log: option.log });
    }
    const contract = macrochain.deploy(contractFactory, option);
    return contract;
  };

  deploy = async <T extends ContractFactory>(
    contractFactory: new () => T,
    option: {
      from?: SignerWithAddress;
      args?: DeployParam<T>;
      log?: boolean;
    } = {
      from: this.deployer,
      log: undefined,
    },
  ): Promise<ContractInstance<T>> => {
    const contractName = contractFactory.name.split("__")[0];
    const factory = (await ethers.getContractFactory(contractName, option.from)) as T;
    let contract: ContractInstance<T>;
    if (option.args && option.args.length > 0) {
      contract = (await factory.deploy(...option.args)) as ContractInstance<T>;
    } else {
      contract = (await factory.deploy()) as ContractInstance<T>;
    }

    if (option.log === undefined) {
      const chainId = hre.network.config.chainId || 31337;
      if (chainId !== 31337 || this.globalLog === true) {
        option.log = true;
      } else {
        option.log = false;
      }
    }

    if (option.log === true) {
      console.log("***********************************");
      console.log("Contract: " + contractName);
      console.log("Address:  " + contract.address);
      console.log("TX hash:  " + contract.deployTransaction.hash);
      console.log("...waiting for confirmation");
    }

    await contract.deployed();

    if (option.log) {
      console.log("Confirmed!");

      const chainId = hre.network.config.chainId || 31337;
      const dir = `./deployments/${chainId}`;
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, {
          recursive: true,
        });
      }

      const file = editJsonFile(dir + "/logs.json");
      const contractLog: ContractLog = {
        address: contract.address,
        txHash: contract.deployTransaction.hash,
        args: option.args || [],
      };
      file.set(contractName, contractLog);
      file.save();
      this.deployedContracts.push(contractName);
    }

    return contract;
  };

  connect = async <T extends ContractFactory>(
    contractFactory: new () => T,
    newAddr?: string,
  ): Promise<ContractInstance<T>> => {
    const contractName = contractFactory.name.split("__")[0];
    const factory = (await ethers.getContractFactory(contractName, this.deployer)) as T;

    if (newAddr) {
      return factory.attach(newAddr) as ContractInstance<T>;
    } else {
      const chainId = hre.network.config.chainId || 31337;
      const file = editJsonFile(`./deployments/${chainId}/logs.json`);
      const addr = file.get(`${contractName}.address`);
      if (addr) {
        return factory.attach(addr) as ContractInstance<T>;
      } else {
        throw "Invalid contract name or contract address";
      }
    }
  };

  verifyDeployedContracts = async (): Promise<void> => {
    if (this.deployedContracts.length > 0) {
      await verifyContract(...this.deployedContracts);
    } else {
      throw "Nothing to verify";
    }
  };
}

export const verifyContract = async (...contracts: string[]): Promise<void> => {
  console.log("***********************************");
  console.log("Begin verification...");
  console.log("(This will take some time. You can already interact with contract while you wait.)");

  const chainId = hre.network.config.chainId || 31337;
  const file = editJsonFile(`./deployments/${chainId}/logs.json`);
  const { length } = contracts;

  await Time.fromMin(2).delay();

  for (let i = 0; i < length; i++) {
    const contract = file.get(contracts[i]) as ContractLog;
    const source = await getContractSource(contracts[i]);

    console.log("***********************************");
    console.log(`Working on contract: ${contract.address} (${i + 1} out of ${length})`);

    if (contract) {
      await hre.run("verify:verify", {
        address: contract.address,
        constructorArguments: contract.args,
        contract: source,
      });
    } else {
      throw "Invalid contract name or the contract does not exist";
    }

    i + 1 < length && (await Time.fromSec(10).delay());
  }

  console.log("...Finished!");
};

const getContractSource = async (contractName: string): Promise<string | undefined> => {
  const sourceNames = (await hre.artifacts.getAllFullyQualifiedNames()) as string[];
  for (let i = 0; i < sourceNames.length; i++) {
    const parts = sourceNames[i].split(":");
    if (parts[1] === contractName) {
      return sourceNames[i];
    }
  }
  return undefined;
};
