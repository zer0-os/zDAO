import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers, network, upgrades } from "hardhat";
import { ZDAORegistry } from "../types";
import { SnapshotZDAOChef } from "../types/SnapshotZDAOChef";
import { config, PlatformType } from "./shared/config";
import { verifyContract } from "./shared/helpers";

const main = async () => {
  const signers = await ethers.getSigners();
  if (signers.length < 1) {
    throw new Error(`Not found deployer`);
  }

  const deployer: SignerWithAddress = signers[0];

  if (
    network.name === "goerli" ||
    network.name === "rinkeby" ||
    network.name === "mainnet"
  ) {
    // ZDAORegistry
    console.log("Deploying ZDAORegistry proxy contract...");
    const ZDAORegistryFactory = await ethers.getContractFactory("ZDAORegistry");
    const zDAORegistry = (await upgrades.deployProxy(
      ZDAORegistryFactory,
      [config[network.name].zNSHub],
      {
        kind: "uups",
        initializer: "__ZDAORegistry_init",
      }
    )) as ZDAORegistry;
    await zDAORegistry.deployed();
    console.log(`\ndeployed: ${zDAORegistry.address}`);

    const zDAORegistryImpl = await upgrades.erc1967.getImplementationAddress(
      zDAORegistry.address
    );
    await verifyContract(zDAORegistryImpl);

    console.table([
      {
        Label: "Deployer address",
        Info: deployer.address,
      },
      {
        Label: "ZDAORegistry proxy address",
        Info: zDAORegistry.address,
      },
      {
        Label: "ZDAORegistry implementation address",
        Info: zDAORegistryImpl,
      },
    ]);

    console.log("\n\nWelcome to Ethereum!");
  }
};

main().catch(console.error);
