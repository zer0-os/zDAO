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

  if (network.name === "rinkeby" || network.name === "mainnet") {
    // ZDAORegistry
    console.log("Deploying ZDAORegistry proxy contract...");
    const ZDAORegistryFactory = await ethers.getContractFactory("ZDAORegistry");
    const zDAORegistry = (await upgrades.deployProxy(
      ZDAORegistryFactory,
      [config[network.name].znsHub],
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

    // SnapshotZDAOChef
    console.log("Deploying SnapshotZDAOChef proxy contract...");
    const SnapshotZDAOChefFactory = await ethers.getContractFactory(
      "SnapshotZDAOChef"
    );
    const snapshotZDAOChef = (await upgrades.deployProxy(
      SnapshotZDAOChefFactory,
      [zDAORegistry.address],
      {
        kind: "uups",
        initializer: "__SnapshotZDAOChef_init",
      }
    )) as SnapshotZDAOChef;
    await snapshotZDAOChef.deployed();
    console.log(`\ndeployed: ${zDAORegistry.address}`);

    const snapshotZDAOChefImpl =
      await upgrades.erc1967.getImplementationAddress(snapshotZDAOChef.address);
    await verifyContract(snapshotZDAOChefImpl);

    console.log("Initializing ZDAORegistry");
    await zDAORegistry.addZDAOFactory(
      PlatformType.Snapshot, // Snapshot platform
      snapshotZDAOChef.address
    );

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
      {
        Label: "SnapshotZDAOChef proxy address",
        Info: snapshotZDAOChef.address,
      },
      {
        Label: "SnapshotZDAOChef implementation address",
        Info: snapshotZDAOChefImpl,
      },
    ]);

    console.log("\n\nWelcome to Ethereum!");
  }
};

main().catch(console.error);
