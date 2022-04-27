import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import * as zns from "@zero-tech/zns-sdk";
import { BigNumber } from "ethers";
import { ethers, network } from "hardhat";
import EtherZDAOAbi from "../artifacts/contracts/ethereum/EtherZDAO.sol/EtherZDAO.json";
import PolyZDAOAbi from "../artifacts/contracts/polygon/PolyZDAO.sol/PolyZDAO.json";
import { EtherZDAO, EtherZDAOChef } from "../types";
import { sleep, verifyContract } from "./shared/helpers";

const contracts = {
  goerli: {
    EtherZDAOBase: "0x89FC44C7A2aFf5e607B2680E86329f5724EF5217",
    EtherZDAOChef: "0x06def0F435879d49420eb9f7E39189696369d510",
    VotingToken: "0xe4dcfb387a4cf3efa2af1186b47ca2a042e37838",
  },
  mainnet: {
    EtherZDAOChef: "", // todo
    EtherZDAOBase: "", // todo
    VotingToken: "", // todo
  },
};

const createZDAO = async (
  network: "goerli" | "mainnet",
  deployer: SignerWithAddress
) => {
  const zDAOChef = (await ethers.getContractAt(
    "EtherZDAOChef",
    contracts[network].EtherZDAOChef,
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

  return zDAO;
};

const createProposal = async (
  network: "goerli" | "mainnet",
  deployer: SignerWithAddress,
  contract: string
) => {
  const zDAO = (await ethers.getContractAt(
    "EtherZDAO",
    contract,
    deployer
  )) as EtherZDAO;

  const proposal = {
    startTimestamp: Math.floor(new Date().getTime() / 1000),
    endTimestamp: Math.floor(new Date().getTime() / 1000) + 300,
    token: contracts[network].VotingToken,
    amount: BigNumber.from(10).pow(18),
    ipfs: "0x0170171c23281b16a3c58934162488ad6d039df686eca806f21eba0cebd03486", // random byte32 string
  };
  await zDAO.createProposal(
    proposal.startTimestamp,
    proposal.endTimestamp,
    proposal.token,
    proposal.amount,
    proposal.ipfs
  );
};

const main = async () => {
  const signers = await ethers.getSigners();
  if (signers.length < 1) {
    throw new Error(`Not found deployer`);
  }

  const deployer: SignerWithAddress = signers[0];

  if (network.name === "goerli" || network.name === "mainnet") {
    // const zDAO = await createZDAO(network.name, deployer);
    // console.log(`\nCreated zDAO: ${zDAO}`);

    await createProposal(
      network.name,
      deployer,
      "0xB21e1e84eC9453c13dA7B9027E3ea77D85e992e5"
    );

    console.log("\nWelcome");
  } else if (network.name === "polygonMumbai" || network.name === "polygon") {
    // the below codes are used only for verifying contract
    const zDAOInterface = new ethers.utils.Interface(PolyZDAOAbi.abi);
    const proxyData = zDAOInterface.encodeFunctionData("__ZDAO_init", [
      "0x3196b6604f12C3d3E457b2a71aB1358F16A0fcf0", // PolyZDAOChef
      "0x36F7559E3fEF104a87cD23BC1603b3ca406A9867", // staking
      1, // zDAOId
      "0xbe38561e7fb3d9dd5244bd51ea7440738f10bb46", // mapped token
      true,
      51,
    ]);
    console.log("proxyData", proxyData);

    await verifyContract("0xcB67646d7cE288ff91ED26BefaA04c305884a26c", [
      "0x089aa8E9445d71192604C89ca1624158535d031D",
      proxyData,
    ]);
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
