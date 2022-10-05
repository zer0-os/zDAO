import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers, network, upgrades } from "hardhat";
import { FxStatePolygonTunnel, PolygonZDAOChef, Staking } from "../../types";
import { zDAOChefConfig as config } from "../shared/config";
import { calculateGasMargin, verifyContract } from "../shared/helpers";

const main = async () => {
  const signers = await ethers.getSigners();
  if (signers.length < 1) {
    throw new Error(`Not found deployer`);
  }

  const deployer: SignerWithAddress = signers[0];

  if (network.name === "polygonMumbai" || network.name === "polygon") {
    console.log("Deploying FxStatePolygonTunnel proxy contract...");
    const FxStatePolygonTunnelFactory = await ethers.getContractFactory(
      "FxStatePolygonTunnel"
    );
    const fxStatePolygonTunnel = (await upgrades.deployProxy(
      FxStatePolygonTunnelFactory,
      [config[network.name].fxChild],
      {
        kind: "uups",
        initializer: "__FxStatePolygonTunnel_init",
      }
    )) as FxStatePolygonTunnel;
    await fxStatePolygonTunnel.deployed();
    console.log(`\ndeployed: ${fxStatePolygonTunnel.address}`);

    const fxStatePolygonTunnelImpl =
      await upgrades.erc1967.getImplementationAddress(
        fxStatePolygonTunnel.address
      );
    await verifyContract(fxStatePolygonTunnelImpl);

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

    console.log("Deploying PolygonZDAO implementation contract...");
    const ZDAOFactory = await ethers.getContractFactory("PolygonZDAO");
    const zDAOBase = await ZDAOFactory.deploy();
    await zDAOBase.deployed();
    console.log(`\ndeployed: ${zDAOBase.address}`);

    await verifyContract(zDAOBase.address);

    console.log("Deploying PolygonZDAOChef proxy contract...");
    const ZDAOChefFactory = await ethers.getContractFactory("PolygonZDAOChef");
    const zDAOChef = (await upgrades.deployProxy(
      ZDAOChefFactory,
      [
        staking.address,
        fxStatePolygonTunnel.address,
        zDAOBase.address,
        config[network.name].childChainManager,
      ],
      {
        kind: "uups",
        initializer: "__ZDAOChef_init",
      }
    )) as PolygonZDAOChef;
    await zDAOChef.deployed();
    console.log(`\ndeployed: ${zDAOChef.address}`);

    const zDAOChefImpl = await upgrades.erc1967.getImplementationAddress(
      zDAOChef.address
    );
    await verifyContract(zDAOChefImpl);

    // configuring root tunnel contract
    console.log("Setting ChildStateReceiver in FxStatePolygonTunnel");
    const gasEstimated =
      await fxStatePolygonTunnel.estimateGas.setPolygonStateReceiver(
        zDAOChef.address
      );
    await fxStatePolygonTunnel.setPolygonStateReceiver(zDAOChef.address, {
      gasLimit: calculateGasMargin(gasEstimated),
    });

    console.table([
      {
        Label: "Deployer address",
        Info: deployer.address,
      },
      {
        Label: "FxStatePolygonTunnel proxy address",
        Info: fxStatePolygonTunnel.address,
      },
      {
        Label: "FxStatePolygonTunnel implementation address",
        Info: fxStatePolygonTunnelImpl,
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
        Label: "PolygonZDAOChef proxy address",
        Info: zDAOChef.address,
      },
      {
        Label: "PolygonZDAOChef implementation address",
        Info: zDAOChefImpl,
      },
      {
        Label: "PolygonZDAO base address",
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
