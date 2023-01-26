import * as hre from "hardhat";
import { ZDAORegistry__factory } from "../types";
import { verifyContract } from "./shared/helpers";

// mainnet hub: 0x6141d5cb3517215a03519a464bf9c39814df7479
// rinkeby hub: 0x90098737eB7C3e73854daF1Da20dFf90d521929a
// goerli hub: 0xce1fE2DA169C313Eb00a2bad25103D2B9617b5e1

const znsHubAddress = "0xce1fE2DA169C313Eb00a2bad25103D2B9617b5e1";

const main = async () => {
  const signers = await hre.ethers.getSigners();
  const deployer = signers[0];

  const ZDAORegistryFactory = new ZDAORegistry__factory(deployer);
  const zDAORegistry = await hre.upgrades.deployProxy(ZDAORegistryFactory, [znsHubAddress]);
  console.log(`Deployed to ${zDAORegistry.address}`);

  const zDAORegistryImpl = await hre.upgrades.erc1967.getImplementationAddress(
    zDAORegistry.address
  );
  await verifyContract(zDAORegistryImpl);
  console.log(`Implementation address: ${zDAORegistryImpl}`);
};

main().catch(console.error);
