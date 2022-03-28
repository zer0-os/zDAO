import * as hre from "hardhat";
import { ZDAORegistry__factory } from "../types";

// mainnet hub: 0x6141d5cb3517215a03519a464bf9c39814df7479
// rinkeby hub: 0x90098737eB7C3e73854daF1Da20dFf90d521929a

const znsHubAddress = "0x90098737eB7C3e73854daF1Da20dFf90d521929a";

const main = async () => {
  const signers = await hre.ethers.getSigners();
  const deployer = signers[0];

  const registryFactory = new ZDAORegistry__factory(deployer);
  const proxy = await hre.upgrades.deployProxy(registryFactory, [znsHubAddress]);
  console.log(`Deployed to ${proxy.address}`);
};

main().catch(console.error);
