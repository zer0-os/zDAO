import { ZDAOCore } from "./../types/ZDAOCore.d";
// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat

import { ZDAOCore__factory } from "../types";

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
  // const zDAOCore = await zDAOCoreFactory.deploy();
  const zDAOCore: ZDAOCore = await ethers.getContractAt(
    "zDAOCore",
    "0xe90c505c8092e1c6f2be8b4812ad86bf127ae5df"
  );
  await zDAOCore.addNewDAO("joshupgig.eth", ["0xFe035df35C6fE5578EdE6267883638DB7634DE82"]);
  console.log(await zDAOCore.owner());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
