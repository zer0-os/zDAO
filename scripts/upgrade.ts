import * as hre from "hardhat";
import { ZDAORegistry__factory } from "../types";

const zDAORegistryAddress = "0x0FE5c0564E5F2dcE6a2c77A14A32d12461D23E78";

const main = async () => {
  const signers = await hre.ethers.getSigners();
  const deployer = signers[0];

  const registryFactory = new ZDAORegistry__factory(deployer);
  const proxy = await hre.upgrades.upgradeProxy(zDAORegistryAddress, registryFactory);
};

main().catch(console.error);
