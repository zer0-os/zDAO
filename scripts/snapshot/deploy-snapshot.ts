import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers, network, upgrades } from "hardhat";
import { ZDAORegistry } from "../../types";
import { SnapshotZDAOChef } from "../../types/SnapshotZDAOChef";
import { config, PlatformType } from "../shared/config";
import { verifyContract } from "../shared/helpers";

const main = async () => {
  const signers = await ethers.getSigners();
  if (signers.length < 1) {
    throw new Error(`Not found deployer`);
  }

  const deployer: SignerWithAddress = signers[0];

  if (network.name === "rinkeby" || network.name === "mainnet") {
    // SnapshotZDAOChef
    console.log("Deploying SnapshotZDAOChef proxy contract...");
    const SnapshotZDAOChefFactory = await ethers.getContractFactory(
      "SnapshotZDAOChef"
    );
    const snapshotZDAOChef = (await upgrades.deployProxy(
      SnapshotZDAOChefFactory,
      [config[network.name].zDAORegistry],
      {
        kind: "uups",
        initializer: "__ZDAOChef_init",
      }
    )) as SnapshotZDAOChef;
    await snapshotZDAOChef.deployed();
    console.log(`\ndeployed: ${snapshotZDAOChef.address}`);

    const snapshotZDAOChefImpl =
      await upgrades.erc1967.getImplementationAddress(snapshotZDAOChef.address);
    await verifyContract(snapshotZDAOChefImpl);

    const zDAORegistry = (await ethers.getContractAt(
      "ZDAORegistry",
      config[network.name].zDAORegistry,
      deployer
    )) as ZDAORegistry;
    console.log("Adding SnapshotZDAOChef factory to ZDAORegistry");
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
