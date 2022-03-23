// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat

import { ZDAOCore__factory, ZDAOCoreProxy__factory, ZDAOCore } from "../types";

// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const ZDAOCoreFactory: ZDAOCore__factory = await ethers.getContractFactory("ZDAOCore");

  const ZDAOCore = await ZDAOCoreFactory.deploy();
  await ZDAOCore.deployed();

  const ZDAOCoreProxyFactory: ZDAOCoreProxy__factory = await ethers.getContractFactory(
    "ZDAOCoreProxy"
  );

  const proxy = await ZDAOCoreProxyFactory.deploy(ZDAOCore.address, process.env.PROXY_ADMIN);
  await proxy.deployed();

  const proxyCast: ZDAOCore = await ethers.getContractAt("ZDAOCore", proxy.address);
  const initializeTx = await proxyCast.initialize(process.env.ZNS_HUB);
  await initializeTx.wait();

  await console.log("deployed to:", proxyCast.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
