import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { zer0ProtocolAddresses } from "@zero-tech/zero-contracts";
import { ethers, network, upgrades } from "hardhat";
import { ZDAORegistry__factory } from "../types";
import { getLogger, verifyContract } from "./shared/helpers";

const logger = getLogger("scripts::deploy-zDAO");

const main = async () => {
  const [deployer] = await ethers.getSigners();
  if (!deployer) throw new Error("No deployer found");

  console.log(`Using deployer address ${deployer.address}`);

  if (network.name !== "goerli" && network.name !== "mainnet")
    throw Error("Deploying on an unknown network");

  const zNSHubAddress = zer0ProtocolAddresses[network.name]!.zNS.znsHub;

  const ZDAORegistryFactory = new ZDAORegistry__factory(deployer);
  const zDAORegistry = await upgrades.deployProxy(ZDAORegistryFactory, [zNSHubAddress]);
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
