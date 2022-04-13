import {
  FakeContract,
  MockContract,
  MockContractFactory,
  smock,
} from "@defi-wonderland/smock";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import * as zns from "@zero-tech/zns-sdk";
import chai, { expect } from "chai";
import { BigNumber, ContractTransaction } from "ethers";
import { ethers } from "hardhat";
import ZDAOJson from "../../artifacts/contracts/polygon/PolyZDAO.sol/PolyZDAO.json";
import {
  IERC20Upgradeable,
  IZNSHub,
  PolyZDAO,
  PolyZDAOChef,
  ICheckpointManager,
  IFxStateSender,
  PolyZDAOChef__factory,
  PolyZDAO__factory,
  IChildTunnel,
} from "../../types";
import { increaseTime, mineToBlock } from "../shared/utilities";

chai.use(smock.matchers);

describe("ZDAO", async function () {
  let owner: SignerWithAddress,
    userA: SignerWithAddress,
    userB: SignerWithAddress,
    userC: SignerWithAddress;

  let childTunnel: FakeContract<IChildTunnel>,
    zDAO: MockContract<PolyZDAO>,
    vToken: FakeContract<IERC20Upgradeable>,
    zDAOInfo: any;
  const minAmount = BigNumber.from("10000");
  const minPeriod = 30; // unit in seconds
  const isRelativeMajority = false;
  const threshold = 5000; // 100% percent in 10000

  beforeEach("init setup", async function () {
    [owner, userA, userB, userC] = await ethers.getSigners();

    const ZDAOFactory = (await smock.mock<PolyZDAO__factory>(
      "PolyZDAO"
    )) as MockContractFactory<PolyZDAO__factory>;
    zDAO = (await ZDAOFactory.deploy()) as MockContract<PolyZDAO>;

    childTunnel = (await smock.fake(
      "IChildTunnel"
    )) as FakeContract<IChildTunnel>;

    const zDAOId = 1;
    await zDAO.__ZDAO_init(
      userA.address,
      zDAOId,
      "Mock zDAO",
      owner.address,
      isRelativeMajority,
      threshold
    );

    vToken = (await smock.fake(
      "IERC20Upgradeable"
    )) as FakeContract<IERC20Upgradeable>;

    zDAOInfo = await zDAO.zDAOInfo();
  });

  it("Check zDAO information", async function () {
    expect(zDAOInfo.zDAOId).to.be.equal(1);
    expect(zDAOInfo.owner).to.be.equal(owner.address);
    expect(zDAOInfo.name).to.be.equal("Mock zDAO");
    expect(zDAOInfo.isRelativeMajority).to.be.equal(isRelativeMajority);
    expect(zDAOInfo.threshold.toString()).to.be.equal(threshold.toString());
    expect(zDAOInfo.destroyed).to.be.equal(false);
  });

  const createProposal = async (
    user: SignerWithAddress,
    blocks = 30
  ): Promise<ContractTransaction> => {
    const blockNumber = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNumber);

    const blockTime = 13;
    const startTimestamp = block.timestamp;
    const endTimestamp = startTimestamp + (blockNumber + blocks) * blockTime;

    const proposalId = 1;
    return zDAO.connect(user).createProposal(
      proposalId,
      userA.address,
      startTimestamp,
      endTimestamp,
      vToken.address, // token address on Ethereum
      minAmount.toString(),
      "0x0170171c23281b16a3c58934162488ad6d039df686eca806f21eba0cebd03486" // random byte32 string
    );
  };

  it("Proposal can be created by child tunnel when it receives message from Ethereum", async function () {
    await expect(createProposal(userB)).to.be.revertedWith("Not a ZDAOChef");
    await expect(createProposal(userA)).to.be.not.reverted;

    expect(await zDAO.numberOfProposals()).to.be.equal(1);

    const proposals = await zDAO.listProposals(1, 1);
    expect(proposals.length).to.be.equal(1);
    expect(proposals[0].createdBy).to.be.equal(userA.address);
    expect(proposals[0].token).to.be.equal(vToken.address);
  });

  it("Anyone should be able to vote on proposal", async function () {
    await createProposal(userA);

    const proposalId = 1;
    const choice = 1; // yes
    await expect(zDAO.connect(userB).vote(proposalId, choice)).to.be.not
      .reverted;

    // check if vote again with different choice
    await expect(zDAO.connect(userB).vote(proposalId, choice + 1)).to.be.not
      .reverted;

    const lastChoice = await zDAO.getVoterChoice(proposalId, userB.address);
    expect(lastChoice).to.be.equal(choice + 1);
  });

  it("Only can collect voting result after proposal ends", async function () {
    await createProposal(userA, 10);

    const proposalId = 1;
    const choice = 1; // yes
    await zDAO.connect(userA).vote(proposalId, choice);
    await zDAO.connect(userB).vote(proposalId, choice);
    await zDAO.connect(userC).vote(proposalId, choice + 1);

    await expect(
      zDAO.connect(userC).collectResult(proposalId)
    ).to.be.revertedWith("Not valid for collecting result");

    // mint to the end of proposal
    for (let i = 0; i < 10; i++) {
      await mineToBlock(10);
    }

    zDAO.setVariable("childTunnel", childTunnel.address);
    await expect(zDAO.connect(userC).collectResult(proposalId)).to.be.not
      .reverted;
  });
});
