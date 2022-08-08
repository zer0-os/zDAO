import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers, network, upgrades } from "hardhat";
import {
  EthereumZDAOChef,
  FxStateEthereumTunnel,
  ZDAORegistry,
} from "../../types";
import { config, PlatformType } from "../shared/config";
import { calculateGasMargin, verifyContract } from "../shared/helpers";

// mainnet hub: 0x6141d5cb3517215a03519a464bf9c39814df7479
// rinkeby hub: 0x90098737eB7C3e73854daF1Da20dFf90d521929a

const main = async () => {
  const signers = await ethers.getSigners();
  if (signers.length < 1) {
    throw new Error(`Not found deployer`);
  }

  const deployer: SignerWithAddress = signers[0];

  if (network.name === "goerli" || network.name === "mainnet") {
    console.log("Deploying FxStateEthereumTunnel proxy contract...");
    const FxStateEthereumTunnelFactory = await ethers.getContractFactory(
      "FxStateEthereumTunnel"
    );
    const fxStateEthereumTunnel = (await upgrades.deployProxy(
      FxStateEthereumTunnelFactory,
      [config[network.name].checkpointManager, config[network.name].fxRoot],
      {
        kind: "uups",
        initializer: "__FxStateEthereumTunnel_init",
      }
    )) as FxStateEthereumTunnel;
    await fxStateEthereumTunnel.deployed();
    console.log(`\ndeployed: ${fxStateEthereumTunnel.address}`);

    const fxStateEthereumTunnelImpl =
      await upgrades.erc1967.getImplementationAddress(
        fxStateEthereumTunnel.address
      );
    await verifyContract(fxStateEthereumTunnelImpl);

    console.log("Deploying EthereumZDAO implementation contract...");
    const ZDAOFactory = await ethers.getContractFactory("EthereumZDAO");
    const zDAOBase = await ZDAOFactory.deploy();
    await zDAOBase.deployed();
    console.log(`\ndeployed: ${zDAOBase.address}`);

    await verifyContract(zDAOBase.address);

    console.log("Deploying EthereumZDAOChef proxy contract...");
    const ZDAOChefFactory = await ethers.getContractFactory("EthereumZDAOChef");
    const zDAOChef = (await upgrades.deployProxy(
      ZDAOChefFactory,
      [
        config[network.name].zDAORegistry,
        config[network.name].zDAOModule,
        fxStateEthereumTunnel.address,
        zDAOBase.address,
      ],
      {
        kind: "uups",
        initializer: "__ZDAOChef_init",
      }
    )) as EthereumZDAOChef;
    await zDAOChef.deployed();
    console.log(`\ndeployed: ${zDAOChef.address}`);

    const zDAOChefImpl = await upgrades.erc1967.getImplementationAddress(
      zDAOChef.address
    );
    await verifyContract(zDAOChefImpl);

    // configuring root tunnel contract
    console.log("Setting RootStateReceiver in FxStateEthereumTunnel");
    const gasEstimated =
      await fxStateEthereumTunnel.estimateGas.setEthereumStateReceiver(
        zDAOChef.address
      );
    await fxStateEthereumTunnel.setEthereumStateReceiver(zDAOChef.address, {
      gasLimit: calculateGasMargin(gasEstimated),
    });

    const zDAORegistry = (await ethers.getContractAt(
      "ZDAORegistry",
      config[network.name].zDAORegistry,
      deployer
    )) as ZDAORegistry;
    console.log("Adding SnapshotZDAOChef factory to ZDAORegistry");
    const gasEstimated2 = await zDAORegistry.estimateGas.addZDAOFactory(
      PlatformType.Polygon, // Snapshot platform
      zDAOChef.address
    );
    await zDAORegistry.addZDAOFactory(
      PlatformType.Polygon, // Snapshot platform
      zDAOChef.address,
      {
        gasLimit: calculateGasMargin(gasEstimated2),
      }
    );

    console.table([
      {
        Label: "Deployer address",
        Info: deployer.address,
      },
      {
        Label: "FxStateEthereumTunnel proxy address",
        Info: fxStateEthereumTunnel.address,
      },
      {
        Label: "FxStateEthereumTunnel implementation address",
        Info: fxStateEthereumTunnelImpl,
      },
      {
        Label: "EthereumZDAOChef proxy address",
        Info: zDAOChef.address,
      },
      {
        Label: "EthereumZDAOChef implementation address",
        Info: zDAOChefImpl,
      },
      {
        Label: "EthereumZDAO base address",
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
