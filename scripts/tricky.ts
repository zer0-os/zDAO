import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers, network, upgrades } from "hardhat";
import { encodeCreateZDAO } from "../test/shared/messagePack";
import { IPolygonZDAO, PolygonZDAO } from "../types";
import { config } from "./shared/config";
import { verifyContract } from "./shared/helpers";

const checkPolygonZDAO = async (
  deployer: SignerWithAddress,
  contract: string
) => {
  // const polyZDAO = (await ethers.getContractAt(
  //   "PolygonZDAO",
  //   contract,
  //   deployer
  // )) as PolygonZDAO;
  // const childTunnel = await polyZDAO.childTunnel();
  // console.log("childTunnel", childTunnel);
  // const staking = await polyZDAO.staking();
  // console.log("staking", staking);
  // const zDAOInfo = await polyZDAO.zDAOInfo();
  // console.log("zDAOInfo", zDAOInfo);
  // const numberOfProposals = await polyZDAO.numberOfProposals();
  // console.log("numberOfProposals", numberOfProposals);
  // const proposals = await polyZDAO.listProposals(1, numberOfProposals);
  // console.log("proposals", proposals);
  // console.log(">> now", new Date().getTime());
  // proposals.forEach((proposal: IPolygonZDAO.ProposalStruct, index: number) => {
  //   const now = new Date();
  //   if (Number(proposal.endTimestamp) < now.getTime()) {
  //     console.log(`> ${index + 1}th proposal closed`);
  //   } else {
  //     console.log(`> ${index + 1}th proposal active`);
  //   }
  // });
};

const main = async () => {
  const signers = await ethers.getSigners();
  if (signers.length < 1) {
    throw new Error(`Not found deployer`);
  }

  const deployer: SignerWithAddress = signers[0];

  if (network.name === "goerli" || network.name === "mainnet") {
    const payload = encodeCreateZDAO({
      lastZDAOId: 1,
    });

    console.log("payload", payload);

    console.log("\nWelcome");
  } else if (network.name === "polygonMumbai" || network.name === "polygon") {
    await checkPolygonZDAO(
      deployer,
      "0xcB67646d7cE288ff91ED26BefaA04c305884a26c"
    );
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
