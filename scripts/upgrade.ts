import * as hre from "hardhat";
import { ZDAORegistry__factory } from "../types";
import { verifyContract } from "./shared/helpers";

// mainnet zDAORegistry: 0x7701913b65C9bCDa4d353F77EC12123d57D77f1e
// rinkeby zDAORegistry: 0x73D44dEa3A3334aB2504443479aD531FfeD2d2D9
// goerli zDAORegistry: 0x4d681D8245e956E1cb295Abe870DF6736EA5F70e

const zDAORegistryAddress = "0x7701913b65C9bCDa4d353F77EC12123d57D77f1e";

const main = async () => {
  const signers = await hre.ethers.getSigners();
  const deployer = signers[0];

  const ZDAORegistryFactory = new ZDAORegistry__factory(deployer);
  const zDAORegistry = await hre.upgrades.upgradeProxy(
    zDAORegistryAddress,
    ZDAORegistryFactory,
    {}
  );
  console.log(`Upgraded to ${zDAORegistry.address}`);

  const zDAORegistryImpl = await hre.upgrades.erc1967.getImplementationAddress(
    zDAORegistry.address
  );
  await verifyContract(zDAORegistryImpl);
  console.log(`Implementation address: ${zDAORegistryImpl}`);
};

main().catch(console.error);
