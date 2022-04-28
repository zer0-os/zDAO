import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers, network, upgrades } from "hardhat";
import { EtherZDAOChef, FxStateRootTunnel } from "../types";
import { config } from "./shared/config";
import { verifyContract } from "./shared/helpers";

// mainnet hub: 0x6141d5cb3517215a03519a464bf9c39814df7479
// rinkeby hub: 0x90098737eB7C3e73854daF1Da20dFf90d521929a

const main = async () => {
  const signers = await ethers.getSigners();
  if (signers.length < 1) {
    throw new Error(`Not found deployer`);
  }

  const deployer: SignerWithAddress = signers[0];

  if (network.name === "goerli" || network.name === "mainnet") {
    console.log("Deploying FxStateRootTunnel proxy contract...");
    const FxStateRootTunnelFactory = await ethers.getContractFactory(
      "FxStateRootTunnel"
    );
    const fxStateRootTunnel = (await upgrades.deployProxy(
      FxStateRootTunnelFactory,
      [config[network.name].checkpointManager, config[network.name].fxRoot],
      {
        kind: "uups",
        initializer: "__FxStateRootTunnel_init",
      }
    )) as FxStateRootTunnel;
    await fxStateRootTunnel.deployed();
    console.log(`\ndeployed: ${fxStateRootTunnel.address}`);

    const fxStateRootTunnelImpl =
      await upgrades.erc1967.getImplementationAddress(
        fxStateRootTunnel.address
      );
    await verifyContract(fxStateRootTunnelImpl);

    console.log("Deploying EtherZDAO implementation contract...");
    const ZDAOFactory = await ethers.getContractFactory("EtherZDAO");
    const zDAOBase = await ZDAOFactory.deploy();
    await zDAOBase.deployed();
    console.log(`\ndeployed: ${zDAOBase.address}`);

    await verifyContract(zDAOBase.address);

    console.log("Deploying EtherZDAOChef proxy contract...");
    const ZDAOChefFactory = await ethers.getContractFactory("EtherZDAOChef");
    const zDAOChef = (await upgrades.deployProxy(
      ZDAOChefFactory,
      [
        config[network.name].znsHub,
        fxStateRootTunnel.address,
        zDAOBase.address,
      ],
      {
        kind: "uups",
        initializer: "__ZDAOChef_init",
      }
    )) as EtherZDAOChef;
    await zDAOChef.deployed();
    console.log(`\ndeployed: ${zDAOChef.address}`);

    const zDAOChefImpl = await upgrades.erc1967.getImplementationAddress(
      zDAOChef.address
    );
    await verifyContract(zDAOChefImpl);

    // configuring root tunnel contract
    console.log("Setting ChildStateReceiver in FxStateRootTunnel");
    await fxStateRootTunnel.setRootStateReceiver(zDAOChef.address);

    console.table([
      {
        Label: "Deployer address",
        Info: deployer.address,
      },
      {
        Label: "FxStateRootTunnel proxy address",
        Info: fxStateRootTunnel.address,
      },
      {
        Label: "FxStateRootTunnel implementation address",
        Info: fxStateRootTunnelImpl,
      },
      {
        Label: "EtherZDAOChef proxy address",
        Info: zDAOChef.address,
      },
      {
        Label: "EtherZDAOChef implementation address",
        Info: zDAOChefImpl,
      },
      {
        Label: "EtherZDAO base address",
        Info: zDAOBase.address,
      },
    ]);

    console.log("\n\nWelcome to Ethereum!");
  }
};

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
