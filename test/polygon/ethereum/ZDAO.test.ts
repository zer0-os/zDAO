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
import {
  IERC20Upgradeable,
  EthereumZDAO,
  EthereumZDAO__factory,
} from "../../../types";
import { ProposalConfig, ZDAOConfig } from "../../shared/types";
import { mineToBlock, now } from "../../shared/utilities";

chai.use(smock.matchers);

describe("ZDAO", async function () {
  let owner: SignerWithAddress,
    zDAOChef: SignerWithAddress,
    zNAOwner: SignerWithAddress,
    userA: SignerWithAddress,
    userB: SignerWithAddress;

  const zNA = "wilder.wheels";

  let zDAO: MockContract<EthereumZDAO>,
    vToken: FakeContract<IERC20Upgradeable>,
    zDAOInfo: any;

  let gnosisSafe: string,
    zDAOConfig: ZDAOConfig,
    proposalConfig: ProposalConfig;

  beforeEach("init setup", async function () {
    [owner, zDAOChef, zNAOwner, userA, userB] = await ethers.getSigners();

    const ZDAOFactory = (await smock.mock<EthereumZDAO__factory>(
      "EthereumZDAO"
    )) as MockContractFactory<EthereumZDAO__factory>;
    zDAO = (await ZDAOFactory.deploy()) as MockContract<EthereumZDAO>;

    vToken = (await smock.fake(
      "IERC20Upgradeable"
    )) as FakeContract<IERC20Upgradeable>;

    const zDAOId = 1;
    const minAmount = BigNumber.from("10000");
    const minDuration = 30; // unit in seconds
    const minimumTotalVotingTokens = 5000;
    gnosisSafe = await ethers.Wallet.createRandom().getAddress();

    zDAOConfig = {
      token: vToken.address,
      amount: minAmount.toNumber(),
      duration: minDuration,
      votingDelay: 0,
      votingThreshold: 5001, // 50.01%
      minimumVotingParticipants: 1,
      minimumTotalVotingTokens: 5000,
      isRelativeMajority: true,
    };

    await zDAO.__ZDAO_init(
      zDAOChef.address, // instead of zDAOChef
      zDAOId,
      zNAOwner.address,
      gnosisSafe,
      zDAOConfig
    );

    zDAOInfo = await zDAO.zDAOInfo();

    proposalConfig = {
      choices: ["Approve", "Deny", "Absence"],
      ipfs: "0x0170171c23281b16a3c58934162488ad6d039df686eca806f21eba0cebd03486", // random byte32 string
    };
  });

  it("Check zDAO information", async function () {
    expect(zDAOInfo.zDAOId).to.be.equal(1);
    expect(zDAOInfo.createdBy).to.be.equal(zNAOwner.address);
    expect(zDAOInfo.gnosisSafe).to.be.equal(gnosisSafe);
    expect(zDAOInfo.token).to.be.equal(zDAOConfig.token);
    expect(zDAOInfo.amount.toNumber()).to.be.equal(zDAOConfig.amount);
    expect(zDAOInfo.duration.toNumber()).to.be.equal(zDAOConfig.duration);
    expect(zDAOInfo.votingDelay.toNumber()).to.be.equal(zDAOConfig.votingDelay);
    expect(zDAOInfo.isRelativeMajority).to.be.equal(
      zDAOConfig.isRelativeMajority
    );
    expect(zDAOInfo.minimumTotalVotingTokens).to.be.equal(
      zDAOConfig.minimumTotalVotingTokens
    );
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
        proposalConfig.choices,
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

    const proposals = await zDAO.listProposals(0, 1);
    expect(proposals.length).to.be.equal(1);

    // check proposal informations
    expect(proposals[0].proposalId.toNumber()).to.be.equal(1);
    expect(proposals[0].createdBy).to.be.equal(userA.address);
    expect(proposals[0].choices.length).to.be.equal(
      proposalConfig.choices.length
    );
    proposals[0].choices.forEach((choice, index) =>
      expect(choice).to.be.equal(proposalConfig.choices[index])
    );
    expect(proposals[0].ipfs).to.be.equal(proposalConfig.ipfs);
    expect(proposals[0].snapshot.toNumber()).to.be.greaterThan(0);
    expect(proposals[0].canceled).to.be.equal(false);
  });

  it("Should be callable by zDAOChef", async function () {
    await expect(
      zDAO
        .connect(userB)
        .modifyZDAO(gnosisSafe, vToken.address, zDAOConfig.amount)
    ).to.be.revertedWith("Not a ZDAOChef");
    await expect(
      zDAO
        .connect(zDAOChef)
        .modifyZDAO(gnosisSafe, vToken.address, zDAOConfig.amount)
    ).to.be.not.reverted;
  });

  it("Should receive voting result", async function () {
    // create proposal
    vToken.balanceOf.whenCalledWith(userA.address).returns(zDAOConfig.amount);
    await createProposal(userA);

    await mineToBlock(10);

    const proposalId = 1;

    await expect(
      zDAO.connect(zDAOChef).calculateProposal(proposalId, 1, [70, 20, 10])
    ).to.be.not.reverted;

    const proposal = await zDAO.getProposalById(proposalId);

    // check received result
    expect(proposal.proposalId.toNumber()).to.be.equal(proposalId);
    expect(proposal.votes[0].toNumber()).to.be.equal(70);
    expect(proposal.votes[1].toNumber()).to.be.equal(20);
    expect(proposal.votes[2].toNumber()).to.be.equal(10);
  });

  it("Only proposal creator can cancel the proposal", async function () {
    // create proposal
    vToken.balanceOf.whenCalledWith(userA.address).returns(zDAOConfig.amount);
    await createProposal(userA);

    const proposalId = 1;
    await expect(
      zDAO.connect(zDAOChef).cancelProposal(userB.address, proposalId)
    ).to.be.revertedWith("Not a proposal creator");
    await expect(
      zDAO.connect(zDAOChef).cancelProposal(userA.address, proposalId)
    ).to.be.not.reverted;
  });
});
