import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers, network, upgrades } from "hardhat";
import { ZDAOModule } from "../types/ZDAOModule";
import { verifyContract } from "./shared/helpers";
import config from "./shared/config";

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
    // ZDAOModule
    console.log("Deploying ZDAOModule proxy contract...");
    const ZDAOModuleFactory = await ethers.getContractFactory("ZDAOModule");
    const zDAOModule = (await upgrades.deployProxy(
      ZDAOModuleFactory,
      [config.module[network.name].gnosisSafeProxy],
      {
        kind: "uups",
        initializer: "__ZDAOModule_init",
      }
    )) as ZDAOModule;
    await zDAOModule.deployed();
    console.log(`\ndeployed: ${zDAOModule.address}`);

    const zDAOModuleImpl = await upgrades.erc1967.getImplementationAddress(
      zDAOModule.address
    );
    await verifyContract(zDAOModuleImpl);

    console.table([
      {
        Label: "Deployer address",
        Info: deployer.address,
      },
      {
        Label: "ZDAOModule proxy address",
        Info: zDAOModule.address,
      },
      {
        Label: "ZDAOModule implementation address",
        Info: zDAOModuleImpl,
      },
    ]);

    console.log("\n\nWelcome to Ethereum!");
  }
};

main().catch(console.error);
