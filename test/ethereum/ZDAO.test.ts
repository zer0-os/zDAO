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
import { ProposalConfig, ZDAOConfig } from "../shared/types";
import { mineToBlock, now } from "../shared/utilities";

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
    const minDuration = 30; // unit in seconds
    const quorumVotes = 5000;
    const gnosisSafe = await ethers.Wallet.createRandom().getAddress();

    zDAOConfig = {
      title: `${zNA}.dao`,
      gnosisSafe,
      token: vToken.address,
      amount: minAmount.toNumber(),
      threshold: 5001, // 50.01%
      quorumParticipants: 1,
      quorumVotes: 5000,
      isRelativeMajority: true,
    };

    await zDAO.__ZDAO_init(
      zDAOChef.address, // instead of zDAOChef
      zDAOId,
      zNAOwner.address,
      zDAOConfig
    );

    zDAOInfo = await zDAO.zDAOInfo();

    proposalConfig = {
      duration: minDuration,
      target: vToken.address,
      value: minAmount.toNumber(),
      data: "0x00",
      ipfs: "0x0170171c23281b16a3c58934162488ad6d039df686eca806f21eba0cebd03486", // random byte32 string
    };
  });

  it("Check zDAO information", async function () {
    expect(zDAOInfo.zDAOId).to.be.equal(1);
    expect(zDAOInfo.title).to.be.equal(zDAOConfig.title);
    expect(zDAOInfo.createdBy).to.be.equal(zNAOwner.address);
    expect(zDAOInfo.gnosisSafe).to.be.equal(zDAOConfig.gnosisSafe);
    expect(zDAOInfo.token).to.be.equal(zDAOConfig.token);
    expect(zDAOInfo.amount.toNumber()).to.be.equal(zDAOConfig.amount);
    expect(zDAOInfo.isRelativeMajority).to.be.equal(
      zDAOConfig.isRelativeMajority
    );
    expect(zDAOInfo.quorumVotes).to.be.equal(zDAOConfig.quorumVotes);
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
        proposalConfig.duration,
        proposalConfig.target,
        proposalConfig.value,
        proposalConfig.data,
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
    expect(proposals[0].duration).to.be.equal(proposalConfig.duration);
    expect(proposals[0].yes.toNumber()).to.be.equal(0);
    expect(proposals[0].no.toNumber()).to.be.equal(0);
    expect(proposals[0].ipfs).to.be.equal(proposalConfig.ipfs);
    expect(proposals[0].target).to.be.equal(proposalConfig.target);
    expect(proposals[0].value.toNumber()).to.be.equal(proposalConfig.value);
    expect(proposals[0].data).to.be.equal(proposalConfig.data);
    expect(proposals[0].snapshot.toNumber()).to.be.greaterThan(0);
    expect(proposals[0].executed).to.be.equal(false);
    expect(proposals[0].canceled).to.be.equal(false);
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

    await mineToBlock(10);

    const proposalId = 1;

    await expect(zDAO.connect(zDAOChef).collectProposal(proposalId, 1, 70, 30)).to.be.not.reverted;

    const proposal = await zDAO.proposals(proposalId);

    // check received result
    expect(proposal.yes.toNumber()).to.be.equal(70);
    expect(proposal.no.toNumber()).to.be.equal(30);
  });
});
