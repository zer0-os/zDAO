import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import * as zns from "@zero-tech/zns-sdk";
import { BigNumber } from "ethers";
import { ethers, network } from "hardhat";
import EtherZDAOAbi from "../artifacts/contracts/ethereum/EtherZDAO.sol/EtherZDAO.json";
import { EtherZDAOChef } from "../types";
import { sleep, verifyContract } from "./shared/helpers";

const contracts = {
  goerli: {
    EtherZDAOBase: "0xbB576de2ca9E6807b151E8d4f710fACf9Eff5DeD",
    EtherZDAOChef: "0x8bB8E594EA003865a4Fa49E3a100c4dFF3C30538",
  },
  mainnet: {
    EtherZDAOChef: "", // todo
    EtherZDAOBase: "", // todo
  },
};

const main = async () => {
  const signers = await ethers.getSigners();
  if (signers.length < 1) {
    throw new Error(`Not found deployer`);
  }

  const deployer: SignerWithAddress = signers[0];

  if (network.name === "goerli" || network.name === "mainnet") {
    const zDAOChef = (await ethers.getContractAt(
      "EtherZDAOChef",
      contracts[network.name].EtherZDAOChef,
      deployer
    )) as EtherZDAOChef;

    // const zNA = "wilder.kicks";
    // const zNA = "wilder.wheels";
    const zNA = "wilder.death";
    const zDAOConfig = {
      name: `${zNA}.dao`,
      gnosisSafe: "0x7a935d07d097146f143A45aA79FD8624353abD5D",
      token: "0xE4DCfb387a4cF3eFa2Af1186B47Ca2a042e37838", // todo, should be voting token on Ethereum/Goerli network
      amount: BigNumber.from(10).pow(18), // 10^18
      minPeriod: 300, // at least 5 min in seconds
      isRelativeMajority: true,
      threshold: 51,
    };

    const zNAId = zns.domains.domainNameToId(zNA);
    console.log("zNAId", zNAId);
    await zDAOChef.addNewDAO(zNAId, zDAOConfig);

    console.log("Sleeping for 60 seconds to wait until deploy");
    await sleep(60000);

    const zDAOBase = await zDAOChef.zDAOBase();
    // get last created zDAO
    const zDAORecord = await zDAOChef.getzDaoByZNA(BigNumber.from(zNAId));
    console.log("zDAORecord", zDAORecord);

    const zDAOId = zDAORecord[0];
    const zDAO = zDAORecord[1];

    const zDAOInterface = new ethers.utils.Interface(EtherZDAOAbi.abi);
    const proxyData = zDAOInterface.encodeFunctionData("__ZDAO_init", [
      zDAOChef.address,
      zDAOId,
      deployer.address,
      zDAOConfig,
    ]);
    console.log("proxyData", proxyData);

    await verifyContract(zDAO, [zDAOBase, proxyData]);
  }
};

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
