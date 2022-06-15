import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers, network, upgrades } from "hardhat";
import { FxStateChildTunnel, ChildZDAOChef, Staking } from "../../types";
import { config } from "../shared/config";
import { verifyContract } from "../shared/helpers";

const main = async () => {
  const signers = await ethers.getSigners();
  if (signers.length < 1) {
    throw new Error(`Not found deployer`);
  }

  const deployer: SignerWithAddress = signers[0];

  if (network.name === "polygonMumbai" || network.name === "polygon") {
    console.log("Deploying FxStateChildTunnel proxy contract...");
    const FxStateChildTunnelFactory = await ethers.getContractFactory(
      "FxStateChildTunnel"
    );
    const fxStateChildTunnel = (await upgrades.deployProxy(
      FxStateChildTunnelFactory,
      [config[network.name].fxChild],
      {
        kind: "uups",
        initializer: "__FxStateChildTunnel_init",
      }
    )) as FxStateChildTunnel;
    await fxStateChildTunnel.deployed();
    console.log(`\ndeployed: ${fxStateChildTunnel.address}`);

    const fxStateChildTunnelImpl =
      await upgrades.erc1967.getImplementationAddress(
        fxStateChildTunnel.address
      );
    await verifyContract(fxStateChildTunnelImpl);

    // Staking
    console.log("Deploying Staking proxy contract...");
    const StakingFactory = await ethers.getContractFactory("Staking");
    const staking = (await upgrades.deployProxy(StakingFactory, [], {
      kind: "uups",
      initializer: "__Staking_init",
    })) as Staking;
    await staking.deployed();
    console.log(`\ndeployed: ${staking.address}`);

    const stakingImpl = await upgrades.erc1967.getImplementationAddress(
      staking.address
    );
    await verifyContract(stakingImpl);

    console.log("Deploying ChildZDAO implementation contract...");
    const ZDAOFactory = await ethers.getContractFactory("ChildZDAO");
    const zDAOBase = await ZDAOFactory.deploy();
    await zDAOBase.deployed();
    console.log(`\ndeployed: ${zDAOBase.address}`);

    await verifyContract(zDAOBase.address);

    console.log("Deploying ChildZDAOChef proxy contract...");
    const ZDAOChefFactory = await ethers.getContractFactory("ChildZDAOChef");
    const zDAOChef = (await upgrades.deployProxy(
      ZDAOChefFactory,
      [
        staking.address,
        fxStateChildTunnel.address,
        zDAOBase.address,
        config[network.name].childChainManager,
      ],
      {
        kind: "uups",
        initializer: "__ZDAOChef_init",
      }
    )) as ChildZDAOChef;
    await zDAOChef.deployed();
    console.log(`\ndeployed: ${zDAOChef.address}`);

    const zDAOChefImpl = await upgrades.erc1967.getImplementationAddress(
      zDAOChef.address
    );
    await verifyContract(zDAOChefImpl);

    // configuring root tunnel contract
    console.log("Setting ChildStateReceiver in FxStateChildTunnel");
    await fxStateChildTunnel.setChildStateReceiver(zDAOChef.address);

    console.table([
      {
        Label: "Deployer address",
        Info: deployer.address,
      },
      {
        Label: "FxStateChildTunnel proxy address",
        Info: fxStateChildTunnel.address,
      },
      {
        Label: "FxStateChildTunnel implementation address",
        Info: fxStateChildTunnelImpl,
      },
      {
        Label: "ChildChainManager proxy address",
        Info: config[network.name].childChainManager,
      },
      {
        Label: "Staking proxy address",
        Info: staking.address,
      },
      {
        Label: "Staking implementation address",
        Info: stakingImpl,
      },
      {
        Label: "ChildZDAOChef proxy address",
        Info: zDAOChef.address,
      },
      {
        Label: "ChildZDAOChef implementation address",
        Info: zDAOChefImpl,
      },
      {
        Label: "ChildZDAO base address",
        Info: zDAOBase.address,
      },
    ]);

    console.log("\nInitializing contracts");

    console.log("\n\nWelcome to Polygon!");
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
