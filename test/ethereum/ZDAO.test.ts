import {
  FakeContract,
  MockContract,
  MockContractFactory,
  smock,
} from "@defi-wonderland/smock";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import chai, { expect } from "chai";
import { BigNumber, ContractTransaction } from "ethers";
import { ethers } from "hardhat";
import { IERC20Upgradeable, EtherZDAO, EtherZDAO__factory } from "../../types";
import { encodeVoteResult, VoteResultPack } from "../shared/messagePack";
import { ProposalConfig, ZDAOConfig } from "../shared/types";
import { now } from "../shared/utilities";

chai.use(smock.matchers);

describe("ZDAO", async function () {
  let owner: SignerWithAddress,
    zDAOChef: SignerWithAddress,
    zNAOwner: SignerWithAddress,
    userA: SignerWithAddress,
    userB: SignerWithAddress;

  const zNA = "wilder.wheels";

  let zDAO: MockContract<EtherZDAO>,
    vToken: FakeContract<IERC20Upgradeable>,
    zDAOInfo: any;

  let zDAOConfig: ZDAOConfig, proposalConfig: ProposalConfig;

  beforeEach("init setup", async function () {
    [owner, zDAOChef, zNAOwner, userA, userB] = await ethers.getSigners();

    const ZDAOFactory = (await smock.mock<EtherZDAO__factory>(
      "EtherZDAO"
    )) as MockContractFactory<EtherZDAO__factory>;
    zDAO = (await ZDAOFactory.deploy()) as MockContract<EtherZDAO>;

    vToken = (await smock.fake(
      "IERC20Upgradeable"
    )) as FakeContract<IERC20Upgradeable>;

    const zDAOId = 1;
    const minAmount = BigNumber.from("10000");
    const minPeriod = 30; // unit in seconds
    const threshold = 5000; // 100% percent in 10000
    const gnosisSafe = await ethers.Wallet.createRandom().getAddress();

    zDAOConfig = {
      name: `${zNA}.dao`,
      gnosisSafe,
      token: vToken.address,
      amount: minAmount.toNumber(),
      minPeriod,
      isRelativeMajority: true,
      threshold,
    };

    await zDAO.__ZDAO_init(
      zDAOChef.address, // instead of zDAOChef
      zDAOId,
      zNAOwner.address,
      zDAOConfig
    );

    zDAOInfo = await zDAO.zDAOInfo();

    proposalConfig = {
      startTimestamp: await now(),
      endTimestamp: (await now()) + minPeriod,
      token: vToken.address,
      amount: minAmount.toNumber(),
      ipfs: "0x0170171c23281b16a3c58934162488ad6d039df686eca806f21eba0cebd03486", // random byte32 string
    };
  });

  it("Check zDAO information", async function () {
    expect(zDAOInfo.zDAOId).to.be.equal(1);
    expect(zDAOInfo.owner).to.be.equal(zNAOwner.address);
    expect(zDAOInfo.name).to.be.equal(zDAOConfig.name);
    expect(zDAOInfo.gnosisSafe).to.be.equal(zDAOConfig.gnosisSafe);
    expect(zDAOInfo.token).to.be.equal(zDAOConfig.token);
    expect(zDAOInfo.amount.toNumber()).to.be.equal(zDAOConfig.amount);
    expect(zDAOInfo.minPeriod).to.be.equal(zDAOConfig.minPeriod);
    expect(zDAOInfo.isRelativeMajority).to.be.equal(
      zDAOConfig.isRelativeMajority
    );
    expect(zDAOInfo.threshold).to.be.equal(zDAOConfig.threshold);
    expect(zDAOInfo.snapshot).to.be.gt(0);
    expect(zDAOInfo.destroyed).to.be.equal(false);
  });

  const createProposal = async (
    user: SignerWithAddress
  ): Promise<ContractTransaction> => {
    return zDAO
      .connect(zDAOChef)
      .createProposal(
        user.address,
        proposalConfig.startTimestamp,
        proposalConfig.endTimestamp,
        proposalConfig.token,
        proposalConfig.amount,
        proposalConfig.ipfs
      );
  };

  it("Only valid token holder can create proposal", async function () {
    // check if user can not create proposal without holding tokens
    await expect(createProposal(userA)).to.be.revertedWith(
      "Not a valid token holder"
    );

    // check if valid token holder can create proposal
    vToken.balanceOf.whenCalledWith(userA.address).returns(zDAOConfig.amount);
    await expect(createProposal(userA)).to.be.not.reverted;

    // check number of proposals and check if available to list proposals
    expect(await zDAO.numberOfProposals()).to.be.equal(1);

    const proposals = await zDAO.listProposals(1, 1);
    expect(proposals.length).to.be.equal(1);

    // check proposal informations
    expect(proposals[0].proposalId).to.be.equal(1);
    expect(proposals[0].createdBy).to.be.equal(userA.address);
    expect(proposals[0].startTimestamp).to.be.equal(
      proposalConfig.startTimestamp
    );
    expect(proposals[0].endTimestamp).to.be.equal(proposalConfig.endTimestamp);
    expect(proposals[0].ipfs).to.be.equal(proposalConfig.ipfs);
    expect(proposals[0].token).to.be.equal(proposalConfig.token);
    expect(proposals[0].amount.toNumber()).to.be.equal(proposalConfig.amount);
    expect(proposals[0].state).to.be.equal(0); // Active state
  });

  it("Should be callable by zDAOChef", async function () {
    await expect(
      zDAO.connect(userB).setVotingToken(vToken.address, zDAOConfig.amount)
    ).to.be.revertedWith("Not a ZDAOChef");
    await expect(
      zDAO.connect(zDAOChef).setVotingToken(vToken.address, zDAOConfig.amount)
    ).to.be.not.reverted;
  });

  it("Should receive voting result", async function () {
    // create proposal
    vToken.balanceOf.whenCalledWith(userA.address).returns(zDAOConfig.amount);
    await createProposal(userA);

    const proposalId = 1;

    await expect(zDAO.connect(zDAOChef).setVoteResult(proposalId, 70, 30)).to.be
      .not.reverted;

    const proposal = await zDAO.proposals(proposalId);

    // check received result
    expect(proposal.yes.toNumber()).to.be.equal(70);
    expect(proposal.no.toNumber()).to.be.equal(30);
  });
});
