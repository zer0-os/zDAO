import * as hre from "hardhat";
import { ZDAORegistry__factory } from "../types";

const zDAORegistryAddress = "0x4039f12A6606D099558f273e601892B90fd64885";

const main = async () => {
  const signers = await hre.ethers.getSigners();
  const deployer = signers[0];

  const registryFactory = new ZDAORegistry__factory(deployer);
  const proxy = await hre.upgrades.upgradeProxy(zDAORegistryAddress, registryFactory, {});
};

main().catch(console.error);
