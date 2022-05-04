import {
  FakeContract,
  MockContract,
  MockContractFactory,
  smock,
} from "@defi-wonderland/smock";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import chai, { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import ZDAOJson from "../../artifacts/contracts/polygon/PolyZDAO.sol/PolyZDAO.json";
import {
  PolyZDAO,
  PolyZDAOChef,
  PolyZDAOChef__factory,
  IChildStateSender,
  MockTokenUpgradeable__factory,
  MockTokenUpgradeable,
} from "../../types";
import { Staking__factory } from "../../types/factories/Staking__factory";
import { Staking } from "../../types/Staking";
import {
  CreateProposalPack,
  CreateZDAOPack,
  encodeCreateProposal,
  encodeCreateZDAO,
  encodeDeleteZDAO,
} from "../shared/messagePack";

chai.use(smock.matchers);

describe("ZDAOChef", async function () {
  let owner: SignerWithAddress,
    zDAOOwner: SignerWithAddress,
    userA: SignerWithAddress;

  let staking: MockContract<Staking>,
    ZDAOChef: MockContract<PolyZDAOChef>,
    childStateSender: FakeContract<IChildStateSender>,
    vToken: MockContract<MockTokenUpgradeable>;

  let zDAOPack: CreateZDAOPack, proposalPack: CreateProposalPack;

  beforeEach("init setup", async function () {
    [owner, zDAOOwner, userA] = await ethers.getSigners();

    const ZDAOChefFactory = (await smock.mock<PolyZDAOChef__factory>(
      "PolyZDAOChef"
    )) as MockContractFactory<PolyZDAOChef__factory>;
    const ZDAOFactory = await ethers.getContractFactory("PolyZDAO");
    const zDAOBase = await ZDAOFactory.deploy();

    const StakingFactory = (await smock.mock<Staking__factory>(
      "Staking"
    )) as MockContractFactory<Staking__factory>;
    staking = (await StakingFactory.deploy()) as MockContract<Staking>;
    await staking.__Staking_init();

    childStateSender = (await smock.fake(
      "IChildStateSender"
    )) as FakeContract<IChildStateSender>;

    ZDAOChef = (await ZDAOChefFactory.deploy()) as MockContract<PolyZDAOChef>;
    await ZDAOChef.__ZDAOChef_init(
      staking.address,
      childStateSender.address,
      zDAOBase.address
    );

    const VotingTokenFactory = (await smock.mock<MockTokenUpgradeable__factory>(
      "MockTokenUpgradeable"
    )) as MockContractFactory<MockTokenUpgradeable__factory>;
    vToken =
      (await VotingTokenFactory.deploy()) as MockContract<MockTokenUpgradeable>;
    await vToken.__MockTokenUpgradeable_init("vToken", "VT");

    const minAmount = BigNumber.from("10000");
    const minDuration = 300; // unit in seconds
    const quorumVotes = 5000; // minimum token amount to be succeeded

    zDAOPack = {
      lastZDAOId: 1,
    };

    proposalPack = {
      zDAOId: 1,
      proposalId: 1,
      duration: minDuration,
    };
  });

  const createZDAO = async (user: SignerWithAddress) => {
    await ZDAOChef.setVariable("childStateSender", user.address);
    const message = encodeCreateZDAO(zDAOPack);

    return ZDAOChef.connect(user).processMessageFromRoot(message);
  };

  const deleteZDAO = async (user: SignerWithAddress) => {
    await ZDAOChef.setVariable("childStateSender", user.address);
    const message = encodeDeleteZDAO({
      zDAOId: zDAOPack.lastZDAOId,
    });

    return ZDAOChef.connect(user).processMessageFromRoot(message);
  };

  const createProposal = async (user: SignerWithAddress) => {
    await ZDAOChef.setVariable("childStateSender", user.address);
    const messageProposal = encodeCreateProposal(proposalPack);

    return ZDAOChef.connect(user).processMessageFromRoot(messageProposal);
  };

  it("Should be able to create zDAO from the message", async function () {
    await expect(createZDAO(userA)).to.be.not.reverted;

    const zDAOAddr = await ZDAOChef.getzDAOById(1);
    const zDAO = (await ethers.getContractAt(
      ZDAOJson.abi,
      zDAOAddr,
      zDAOOwner
    )) as PolyZDAO;

    const zDAOInfo = await zDAO.zDAOInfo();
    expect(zDAOInfo.zDAOId).to.be.equal(zDAOPack.lastZDAOId);
  });

  it("Should not add same DAO twice", async function () {
    await createZDAO(userA);

    // check if revert when add same
    await expect(createZDAO(userA)).to.be.revertedWith(
      "zDAO was already created"
    );
  });

  it("Should list zDAOs", async function () {
    await createZDAO(userA);

    // already created one DAO
    expect(await ZDAOChef.numberOfzDAOs()).to.be.equal(1);

    const daoId = 1;
    const zDAOAddr = await ZDAOChef.getzDAOById(daoId);

    // list zDAOs
    const zDAOAddrs = await ZDAOChef.listzDAOs(0, 1);
    expect(zDAOAddrs.length).to.be.equal(1);
    expect(zDAOAddrs[0]).to.be.equal(zDAOAddr);
  });

  it("Should be able to delete zDAO from the message", async function () {
    await createZDAO(userA);

    await expect(deleteZDAO(userA)).to.be.not.reverted;

    // check if zDAO is destroyed
    const zDAOAddr = await ZDAOChef.getzDAOById(1);
    const zDAO = (await ethers.getContractAt(
      ZDAOJson.abi,
      zDAOAddr,
      zDAOOwner
    )) as PolyZDAO;

    expect(await zDAO.destroyed()).to.be.equal(true);

    // check if revert to create proposal on deleted zDAO
    await expect(createProposal(userA)).to.be.revertedWith("Already destroyed");
  });

  it("Should be able to create proposal from the message", async function () {
    // check if failed to create proposal without zDAO
    await expect(createProposal(userA)).to.be.revertedWith(
      "Not created zDAO yet"
    );

    // create zDAO first
    await createZDAO(userA);

    const zDAOAddr = await ZDAOChef.getzDAOById(1);
    const zDAO = (await ethers.getContractAt(
      ZDAOJson.abi,
      zDAOAddr,
      zDAOOwner
    )) as PolyZDAO;

    // try to create proposal again
    await expect(createProposal(userA)).to.be.not.reverted;

    // check if revert when add same
    await expect(createProposal(userA)).to.be.revertedWith(
      "Proposal was already created"
    );

    expect(await zDAO.numberOfProposals()).to.be.equal(1);
    const proposals = await zDAO.listProposals(0, 1);

    expect(proposals[0].proposalId).to.be.equal(proposalPack.proposalId);
    expect(
      proposals[0].endTimestamp.toNumber() -
        proposals[0].startTimestamp.toNumber()
    ).to.be.equal(proposalPack.duration);
    expect(proposals[0].yes.toNumber()).to.be.equal(0);
    expect(proposals[0].no.toNumber()).to.be.equal(0);
    expect(proposals[0].snapshot.toNumber()).to.be.greaterThan(0);
    expect(proposals[0].executed).to.be.equal(false);
    expect(proposals[0].canceled).to.be.equal(false);
  });
});
