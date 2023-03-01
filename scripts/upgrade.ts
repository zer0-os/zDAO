import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers, network, upgrades } from "hardhat";
import * as manifestGoerli from "../.openzeppelin/goerli.json";
import * as manifestMainnet from "../.openzeppelin/mainnet.json";
import { ZDAORegistryV2__factory } from "../types";
import { getLogger, verifyContract } from "./shared/helpers";

const logger = getLogger("scripts::deploy-zDAO");

const main = async () => {
  const [deployer] = await ethers.getSigners();
  if (!deployer) throw new Error("No deployer found");

  logger.log(`Using deployer address ${deployer.address}`);

  if (network.name !== "goerli" && network.name !== "mainnet")
    throw Error("Deploying on an unknown network");

  const proxyAddr =
    network.name === "goerli"
      ? manifestGoerli.proxies[0].address
      : manifestMainnet.proxies[0].address;

  const ZDAORegistryFactory = new ZDAORegistryV2__factory(deployer);
  const zDAORegistry = await upgrades.upgradeProxy(proxyAddr, ZDAORegistryFactory);
  logger.log(`Deployed to ${zDAORegistry.address}`);

  const zDAORegistryImpl = await upgrades.erc1967.getImplementationAddress(zDAORegistry.address);
  logger.log(`Implementation address: ${zDAORegistryImpl}`);
  await verifyContract(zDAORegistryImpl);

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
};

main().catch(console.error);
