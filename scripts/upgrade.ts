import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers, network, upgrades } from "hardhat";
import * as manifestGoerli from "../.openzeppelin/goerli.json";
import * as manifestMainnet from "../.openzeppelin/mainnet.json";
import { ZDAORegistryV2__factory } from "../types";
import { verifyContract } from "./shared/helpers";

// mainnet hub: 0x6141d5cb3517215a03519a464bf9c39814df7479
// rinkeby hub: 0x90098737eB7C3e73854daF1Da20dFf90d521929a
// goerli hub: 0xce1fE2DA169C313Eb00a2bad25103D2B9617b5e1

const main = async () => {
  const signers = await ethers.getSigners();
  if (signers.length < 1) {
    throw new Error(`Not found deployer`);
  }

  const deployer: SignerWithAddress = signers[0];
  console.log(`Using deployer address ${deployer.address}`);

  if (
    network.name === "goerli" ||
    // network.name === "hardhat" ||
    network.name === "mainnet"
  ) {
    const proxyAddr =
      network.name === "goerli"
        ? manifestGoerli.proxies[0].address
        : manifestMainnet.proxies[0].address;

    const ZDAORegistryFactory = new ZDAORegistryV2__factory(deployer);
    const zDAORegistry = await upgrades.upgradeProxy(proxyAddr, ZDAORegistryFactory);
    console.log(`Deployed to ${zDAORegistry.address}`);

    const zDAORegistryImpl = await upgrades.erc1967.getImplementationAddress(
      zDAORegistry.address
    );
    await verifyContract(zDAORegistryImpl);
    console.log(`Implementation address: ${zDAORegistryImpl}`);

    console.table([
      {
        Label: "Deployer",
        Info: deployer.address,
      },
      {
        Label: "zDAORegistry",
        Info: zDAORegistry.address,
      },
      {
        Label: "zDAORegistry impl",
        Info: zDAORegistryImpl,
      },
    ]);
  }
};

main().catch(console.error);
