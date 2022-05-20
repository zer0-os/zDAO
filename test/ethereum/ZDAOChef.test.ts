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
import ZDAOJson from "../../artifacts/contracts/ethereum/EtherZDAO.sol/EtherZDAO.json";
import {
  ERC20Upgradeable,
  ERC20Upgradeable__factory,
  EtherZDAO,
  EtherZDAOChef,
  EtherZDAOChef__factory,
  IERC20Upgradeable,
  IZNSHub,
  MockTokenUpgradeable,
  MockTokenUpgradeable__factory,
} from "../../types";
import { IRootStateSender } from "../../types/IRootStateSender";
import { encodeCollectProposal } from "../shared/messagePack";
import { ProposalConfig, ZDAOConfig } from "../shared/types";
import { increaseTime, mineToBlock, now } from "../shared/utilities";

chai.use(smock.matchers);

describe("ZDAOChef", async function () {
  let owner: SignerWithAddress,
    zNAOwner: SignerWithAddress,
    zNAOwner2: SignerWithAddress,
    userA: SignerWithAddress,
    userB: SignerWithAddress;

  const zNA = "wilder.wheels";
  const zNAAsNumber = zns.domains.domainNameToId(zNA);
  const zNA2 = "wilder.cat";
  const zNAAsNumber2 = zns.domains.domainNameToId(zNA2);

  let ZNSHub: FakeContract<IZNSHub>,
    rootStateSender: FakeContract<IRootStateSender>,
    ZDAOChef: MockContract<EtherZDAOChef>,
    vToken: FakeContract<IERC20Upgradeable>;

  let zDAOConfig: ZDAOConfig, proposalConfig: ProposalConfig;

  beforeEach("init setup", async function () {
    [owner, zNAOwner, zNAOwner2, userA, userB] = await ethers.getSigners();

    const ZDAOChefFactory = (await smock.mock<EtherZDAOChef__factory>(
      "EtherZDAOChef"
    )) as MockContractFactory<EtherZDAOChef__factory>;
    const ZDAOFactory = await ethers.getContractFactory("EtherZDAO");
    const zDAOBase = await ZDAOFactory.deploy();

    rootStateSender = (await smock.fake(
      "IRootStateSender"
    )) as FakeContract<IRootStateSender>;

    const znsHubAddress = await ethers.Wallet.createRandom().getAddress();

    ZDAOChef = (await ZDAOChefFactory.deploy()) as MockContract<EtherZDAOChef>;
    await ZDAOChef.__ZDAOChef_init(
      znsHubAddress,
      rootStateSender.address,
      zDAOBase.address
    );

    ZNSHub = (await smock.fake("IZNSHub", {
      address: znsHubAddress,
    })) as FakeContract<IZNSHub>;
    // make sure that `owner` is owner of zNA
    ZNSHub.ownerOf.whenCalledWith(zNAAsNumber).returns(zNAOwner.address);
    ZNSHub.ownerOf.whenCalledWith(zNAAsNumber2).returns(zNAOwner2.address);

    vToken = (await smock.fake(
      "IERC20Upgradeable"
    )) as FakeContract<IERC20Upgradeable>;

    const gnosisSafe = await ethers.Wallet.createRandom().getAddress();
    const minAmount = BigNumber.from("10000");
    const minDuration = 30; // unit in seconds
    const minimumTotalVotingTokens = 5000;

    zDAOConfig = {
      title: `${zNA}.dao`,
      gnosisSafe: gnosisSafe,
      token: vToken.address,
      amount: minAmount.toNumber(),
      duration: minDuration,
      votingThreshold: 5001, // 50.01%
      minimumVotingParticipants: 1,
      minimumTotalVotingTokens: minimumTotalVotingTokens,
      isRelativeMajority: true,
    };

    proposalConfig = {
      ipfs: "0x0170171c23281b16a3c58934162488ad6d039df686eca806f21eba0cebd03486", // random byte32 string
    };
  });

  const addNewDAO = (user: SignerWithAddress): Promise<ContractTransaction> => {
    return ZDAOChef.connect(user).addNewDAO(zNAAsNumber, zDAOConfig);
  };

  const createProposal = (
    user: SignerWithAddress,
    daoId: number
  ): Promise<ContractTransaction> => {
    return ZDAOChef.connect(user).createProposal(daoId, proposalConfig.ipfs);
  };

  it("Only zNA owner can add new DAO", async function () {
    // zNA owner can call without revert
    await expect(addNewDAO(zNAOwner)).to.be.not.reverted;

    // other users can't call without revert
    await expect(addNewDAO(userA)).to.be.revertedWith("Not a zNA owner");
  });

  it("Should not add same DAO twice", async function () {
    await addNewDAO(zNAOwner);

    await expect(addNewDAO(zNAOwner)).to.be.revertedWith(
      "Do not allow to add new DAO with same zNA"
    );
  });

  it("Should list zDAOs", async function () {
    await addNewDAO(zNAOwner);

    // check if zDAO for zNA already exist
    expect(await ZDAOChef.doeszDAOExistForzNA(zNAAsNumber)).to.be.equal(true);

    // already created one DAO
    expect(await ZDAOChef.numberOfzDAOs()).to.be.equal(1);

    const daoId = 1;
    const zDAORecord = await ZDAOChef.getzDAOById(daoId);

    expect(zDAORecord.id).to.be.equal(daoId);
    // check if zNA owner is zDAO owner
    const zDAO = (await ethers.getContractAt(
      ZDAOJson.abi,
      zDAORecord.zDAO,
      zNAOwner
    )) as EtherZDAO;
    expect(await zDAO.zDAOOwner()).to.be.equal(zNAOwner.address);
    // only one zNA association
    expect(zDAORecord.associatedzNAs.length).to.be.equal(1);
    expect(zDAORecord.associatedzNAs[0]).to.be.equal(zNAAsNumber);

    // list zDAOs
    const zDAORecords = await ZDAOChef.listzDAOs(0, 1);
    expect(zDAORecords.length).to.be.equal(1);
    expect(zDAORecords[0].id).to.be.equal(zDAORecord.id);
  });

  it("Only DAO owner can remove DAO", async function () {
    await addNewDAO(zNAOwner);

    const daoId = 1;
    await expect(ZDAOChef.connect(userA).removeDAO(daoId)).to.be.revertedWith(
      "Invalid zDAO Owner"
    );
    // check if zDAO owner owner can remove DAO
    await expect(ZDAOChef.connect(zNAOwner).removeDAO(daoId)).to.be.not
      .reverted;

    expect(await ZDAOChef.numberOfzDAOs()).to.be.equal(1);
  });

  it("Only zNA owner can add/remove association", async function () {
    await addNewDAO(zNAOwner);

    // add association
    const daoId = 1;
    await expect(
      ZDAOChef.connect(zNAOwner).addZNAAssociation(daoId, zNAAsNumber2)
    ).to.be.revertedWith("Not a zNA owner");
    // check if only zNA owner can add association
    await expect(
      ZDAOChef.connect(zNAOwner2).addZNAAssociation(daoId, zNAAsNumber2)
    ).to.be.not.reverted;
    // check if it can not associate again
    await expect(
      ZDAOChef.connect(zNAOwner2).addZNAAssociation(daoId, zNAAsNumber2)
    ).to.be.revertedWith("zNA already linked to DAO");

    // check if zDAO has association
    const zDAORecord = await ZDAOChef.getzDaoByZNA(zNAAsNumber);
    const zDAORecord2 = await ZDAOChef.getzDaoByZNA(zNAAsNumber2);

    expect(zDAORecord.id).to.be.equal(zDAORecord2.id);
    expect(zDAORecord.zDAO).to.be.equal(zDAORecord2.zDAO);
    expect(zDAORecord.associatedzNAs.length).to.be.equal(2);

    // remove association
    await expect(
      ZDAOChef.connect(zNAOwner).removeZNAAssociation(daoId, zNAAsNumber)
    ).to.be.not.reverted;

    // check if already removed association
    expect(await ZDAOChef.doeszDAOExistForzNA(zNAAsNumber)).to.be.equal(false);
    // check if still exist the second association
    expect(await ZDAOChef.doeszDAOExistForzNA(zNAAsNumber2)).to.be.equal(true);

    // check if it can not find zDAO by zNA
    await expect(ZDAOChef.getzDaoByZNA(zNAAsNumber)).to.be.revertedWith(
      "No zDAO associated with zNA"
    );
  });

  it("Only DAO owner can set Gnosis Safe", async function () {
    await addNewDAO(zNAOwner);

    const daoId = 1;
    const newGnosisSafe = await ethers.Wallet.createRandom().getAddress();
    await expect(
      ZDAOChef.connect(zNAOwner).setDAOGnosisSafe(daoId, newGnosisSafe)
    ).to.be.not.reverted;
  });

  it("Only DAO owner can set voting token", async function () {
    await addNewDAO(zNAOwner);

    const daoId = 1;
    const votingToken = await ethers.Wallet.createRandom().getAddress();
    await expect(
      ZDAOChef.connect(zNAOwner).setDAOVotingToken(daoId, votingToken, 1000)
    ).to.be.not.reverted;
  });

  it("Should create a proposal", async function () {
    await addNewDAO(zNAOwner);

    const zDAOId = 1;
    vToken.balanceOf.whenCalledWith(userA.address).returns(zDAOConfig.amount);

    await createProposal(userA, zDAOId);
    await expect(createProposal(userA, zDAOId)).to.be.not.reverted;
  });

  it("Should collect voting result", async function () {
    await addNewDAO(zNAOwner);

    const zDAOId = 1;
    vToken.balanceOf.whenCalledWith(userA.address).returns(zDAOConfig.amount);
    await createProposal(userA, zDAOId);

    await expect(createProposal(userA, zDAOId)).to.be.not.reverted;

    await mineToBlock(10);

    const proposalId = 1;
    const message = encodeCollectProposal({
      zDAOId,
      proposalId,
      voters: 1,
      yes: 70,
      no: 30,
    });

    await ZDAOChef.setVariable("rootStateSender", userA.address);
    await expect(ZDAOChef.connect(userA).processMessageFromChild(message)).to.be
      .not.reverted;

    const zDAORecord = await ZDAOChef.getzDAOById(zDAOId);
    const zDAO = (await ethers.getContractAt(
      "EtherZDAO",
      zDAORecord.zDAO,
      userA
    )) as EtherZDAO;

    const proposal = await zDAO.proposals(proposalId);
    expect(proposal.yes).to.be.equal(70);
    expect(proposal.no).to.be.equal(30);
  });

  it("Should not execute a failed proposal", async function () {
    await addNewDAO(zNAOwner);

    const zDAOId = 1;
    vToken.balanceOf.whenCalledWith(userA.address).returns(zDAOConfig.amount);
    await expect(createProposal(userA, zDAOId)).to.be.not.reverted;

    await increaseTime(30);

    const zDAORecord = await ZDAOChef.getzDAOById(zDAOId);
    const zDAO = (await ethers.getContractAt(
      "EtherZDAO",
      zDAORecord.zDAO,
      userA
    )) as EtherZDAO;
    const zDAOInfo = await zDAO.zDAOInfo();
    const proposalId = 1;

    await ZDAOChef.setVariable("rootStateSender", userA.address);

    // should not execute proposal if proposal state is failed
    await expect(
      ZDAOChef.connect(userA).processMessageFromChild(
        encodeCollectProposal({
          zDAOId,
          proposalId,
          voters: 1,
          yes: zDAOInfo.minimumTotalVotingTokens.toNumber(),
          no: zDAOInfo.minimumTotalVotingTokens.toNumber() + 1,
        })
      )
    ).to.be.not.reverted;

    // should reverted because of invalid target, value and data
    await expect(
      ZDAOChef.connect(userA).executeProposal(zDAOId, proposalId)
    ).to.be.revertedWith("Not a succeeded proposal");
  });

  it("Should execute a succeeded proposal", async function () {
    await addNewDAO(zNAOwner);

    const zDAOId = 1;
    vToken.balanceOf.whenCalledWith(userA.address).returns(zDAOConfig.amount);
    await expect(createProposal(userA, zDAOId)).to.be.not.reverted;

    await increaseTime(30);

    const zDAORecord = await ZDAOChef.getzDAOById(zDAOId);
    const zDAO = (await ethers.getContractAt(
      "EtherZDAO",
      zDAORecord.zDAO,
      userA
    )) as EtherZDAO;
    const zDAOInfo = await zDAO.zDAOInfo();
    const proposalId = 1;

    await ZDAOChef.setVariable("rootStateSender", userA.address);

    // should execute proposal if proposal state is succeeded
    await expect(
      ZDAOChef.connect(userA).processMessageFromChild(
        encodeCollectProposal({
          zDAOId,
          proposalId,
          voters: 1,
          yes: zDAOInfo.minimumTotalVotingTokens.toNumber(),
          no: 30,
        })
      )
    ).to.be.not.reverted;

    await ZDAOChef.setVariable("rootStateSender", rootStateSender.address);

    // should reverted because of invalid target, value and data
    await expect(
      ZDAOChef.connect(userA).executeProposal(zDAOId, proposalId)
    ).to.be.not.reverted;
  });

  it("Should execute by action", async function () {
    const ERC20Factory = (await smock.mock<MockTokenUpgradeable__factory>(
      "MockTokenUpgradeable"
    )) as MockContractFactory<MockTokenUpgradeable__factory>;
    const MockERC20 =
      (await ERC20Factory.deploy()) as MockContract<MockTokenUpgradeable>;
    await MockERC20.__MockTokenUpgradeable_init("VT", "VT");

    await MockERC20.mintFor(userA.address, zDAOConfig.minimumTotalVotingTokens);

    zDAOConfig.token = MockERC20.address;
    zDAOConfig.amount = 100;
    zDAOConfig.minimumTotalVotingTokens = 100000;

    await addNewDAO(zNAOwner);

    const zDAOId = 1;
    const proposalId = 1;

    // proposalConfig.data = MockERC20.interface.encodeFunctionData('balanceOf', [userB.address]);

    console.log("proposalConfig", proposalConfig);

    await createProposal(userA, zDAOId);
    await increaseTime(zDAOConfig.duration);

    const zDAORecord = await ZDAOChef.getzDAOById(zDAOId);
    const zDAO = (await ethers.getContractAt(
      "EtherZDAO",
      zDAORecord.zDAO,
      userA
    )) as EtherZDAO;
    const zDAOInfo = await zDAO.zDAOInfo();

    const rootStateSender = await ZDAOChef.rootStateSender();
    await ZDAOChef.setVariable("rootStateSender", userA.address);

    // should execute proposal if proposal state is succeeded
    await expect(
      ZDAOChef.connect(userA).processMessageFromChild(
        encodeCollectProposal({
          zDAOId,
          proposalId,
          voters: 1,
          yes: zDAOInfo.minimumTotalVotingTokens.toNumber(),
          no: 30,
        })
      )
    ).to.be.not.reverted;

    console.log("can Execute", await zDAO.state(proposalId));

    await ZDAOChef.setVariable("rootStateSender", rootStateSender);
    await ZDAOChef.connect(userA).executeProposal(zDAOId, proposalId);
  });
});
