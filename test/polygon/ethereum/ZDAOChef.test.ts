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
import {
  EthereumZDAO,
  EthereumZDAOChef,
  EthereumZDAOChef__factory,
  IERC20Upgradeable,
  IZNSHub,
  MockTokenUpgradeable,
  MockTokenUpgradeable__factory,
} from "../../../types";
import { IEthereumStateSender } from "../../../types/IEthereumStateSender";
import { encodeCalculateProposal } from "../../shared/messagePack";
import { ProposalConfig, ZDAOConfig } from "../../shared/types";
import { increaseTime, mineToBlock, now } from "../../shared/utilities";

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
    ethereumStateSender: FakeContract<IEthereumStateSender>,
    ZDAOChef: MockContract<EthereumZDAOChef>,
    vToken: FakeContract<IERC20Upgradeable>;

  let gnosisSafe: string,
    zDAOConfig: ZDAOConfig,
    proposalConfig: ProposalConfig;

  beforeEach("init setup", async function () {
    [owner, zNAOwner, zNAOwner2, userA, userB] = await ethers.getSigners();

    const ZDAOChefFactory = (await smock.mock<EthereumZDAOChef__factory>(
      "EthereumZDAOChef"
    )) as MockContractFactory<EthereumZDAOChef__factory>;
    const ZDAOFactory = await ethers.getContractFactory("EthereumZDAO");
    const zDAOBase = await ZDAOFactory.deploy();

    ethereumStateSender = (await smock.fake(
      "IEthereumStateSender"
    )) as FakeContract<IEthereumStateSender>;

    const zDAORegistry = await ethers.Wallet.createRandom().getAddress();
    ZDAOChef =
      (await ZDAOChefFactory.deploy()) as MockContract<EthereumZDAOChef>;
    await ZDAOChef.__ZDAOChef_init(
      zDAORegistry,
      ethereumStateSender.address,
      zDAOBase.address
    );

    const znsHubAddress = await ethers.Wallet.createRandom().getAddress();
    ZNSHub = (await smock.fake("IZNSHub", {
      address: znsHubAddress,
    })) as FakeContract<IZNSHub>;
    // make sure that `owner` is owner of zNA
    ZNSHub.ownerOf.whenCalledWith(zNAAsNumber).returns(zNAOwner.address);
    ZNSHub.ownerOf.whenCalledWith(zNAAsNumber2).returns(zNAOwner2.address);

    vToken = (await smock.fake(
      "IERC20Upgradeable"
    )) as FakeContract<IERC20Upgradeable>;

    gnosisSafe = await ethers.Wallet.createRandom().getAddress();
    const minAmount = BigNumber.from("10000");
    const minDuration = 30; // unit in seconds
    const minimumTotalVotingTokens = 5000;

    zDAOConfig = {
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

  const addNewDAO = async (
    user: SignerWithAddress,
    zDAOId: number
  ): Promise<ContractTransaction> => {
    await ZDAOChef.setVariable("zDAORegistry", user.address);
    return ZDAOChef.connect(user).addNewZDAO(
      zDAOId,
      zNAAsNumber,
      gnosisSafe,
      ethers.utils.defaultAbiCoder.encode(
        [
          "address",
          "uint256",
          "uint256",
          "uint256",
          "uint256",
          "uint256",
          "bool",
        ],
        [
          zDAOConfig.token,
          zDAOConfig.amount,
          zDAOConfig.duration,
          zDAOConfig.votingThreshold,
          zDAOConfig.minimumVotingParticipants,
          zDAOConfig.minimumTotalVotingTokens,
          zDAOConfig.isRelativeMajority,
        ]
      )
    );
  };

  const createProposal = (
    user: SignerWithAddress,
    daoId: number
  ): Promise<ContractTransaction> => {
    return ZDAOChef.connect(user).createProposal(daoId, proposalConfig.ipfs);
  };

  it("Should not add same DAO twice", async function () {
    await addNewDAO(zNAOwner, 1);

    await expect(addNewDAO(zNAOwner, 1)).to.be.reverted;
  });

  it("Should modify Gnosis Safe and voting token", async function () {
    await addNewDAO(zNAOwner, 1);

    const newGnosisSafe = await ethers.Wallet.createRandom().getAddress();

    await expect(
      ZDAOChef.connect(zNAOwner).modifyZDAO(
        1,
        newGnosisSafe,
        ethers.utils.defaultAbiCoder.encode(
          ["address", "uint256"],
          [zDAOConfig.token, zDAOConfig.amount]
        )
      )
    ).to.be.not.reverted;
  });

  it("Should create a proposal", async function () {
    await addNewDAO(zNAOwner, 1);

    const zDAOId = 1;
    vToken.balanceOf.whenCalledWith(userA.address).returns(zDAOConfig.amount);

    await createProposal(userA, zDAOId);
    await expect(createProposal(userA, zDAOId)).to.be.not.reverted;
  });

  it("Should calculate voting result", async function () {
    await addNewDAO(zNAOwner, 1);

    const zDAOId = 1;
    vToken.balanceOf.whenCalledWith(userA.address).returns(zDAOConfig.amount);
    await createProposal(userA, zDAOId);

    await expect(createProposal(userA, zDAOId)).to.be.not.reverted;

    await mineToBlock(10);

    const proposalId = 1;
    const message = encodeCalculateProposal({
      zDAOId,
      proposalId,
      voters: 1,
      yes: 70,
      no: 30,
    });

    await ZDAOChef.setVariable("ethereumStateSender", userA.address);
    await expect(ZDAOChef.connect(userA).processMessageFromChild(message)).to.be
      .not.reverted;

    const rootZDAO = await ZDAOChef.zDAOs(zDAOId);
    const zDAO = (await ethers.getContractAt(
      "EthereumZDAO",
      rootZDAO,
      userA
    )) as EthereumZDAO;

    const proposal = await zDAO.proposals(proposalId);
    expect(proposal.yes).to.be.equal(70);
    expect(proposal.no).to.be.equal(30);
  });

  it("Should not execute a failed proposal", async function () {
    await addNewDAO(zNAOwner, 1);

    const zDAOId = 1;
    vToken.balanceOf.whenCalledWith(userA.address).returns(zDAOConfig.amount);
    await expect(createProposal(userA, zDAOId)).to.be.not.reverted;

    await increaseTime(30);

    const rootZDAO = await ZDAOChef.zDAOs(zDAOId);
    const zDAO = (await ethers.getContractAt(
      "EthereumZDAO",
      rootZDAO,
      userA
    )) as EthereumZDAO;
    const zDAOInfo = await zDAO.zDAOInfo();
    const proposalId = 1;

    await ZDAOChef.setVariable("ethereumStateSender", userA.address);

    // should not execute proposal if proposal state is failed
    await expect(
      ZDAOChef.connect(userA).processMessageFromChild(
        encodeCalculateProposal({
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
    await addNewDAO(zNAOwner, 1);

    const zDAOId = 1;
    vToken.balanceOf.whenCalledWith(userA.address).returns(zDAOConfig.amount);
    await expect(createProposal(userA, zDAOId)).to.be.not.reverted;

    await increaseTime(30);

    const rootZDAO = await ZDAOChef.zDAOs(zDAOId);
    const zDAO = (await ethers.getContractAt(
      "EthereumZDAO",
      rootZDAO,
      userA
    )) as EthereumZDAO;
    const zDAOInfo = await zDAO.zDAOInfo();
    const proposalId = 1;

    await ZDAOChef.setVariable("ethereumStateSender", userA.address);

    // should execute proposal if proposal state is succeeded
    await expect(
      ZDAOChef.connect(userA).processMessageFromChild(
        encodeCalculateProposal({
          zDAOId,
          proposalId,
          voters: 1,
          yes: zDAOInfo.minimumTotalVotingTokens.toNumber(),
          no: 0,
        })
      )
    ).to.be.not.reverted;

    await ZDAOChef.setVariable("ethereumStateSender", ethereumStateSender.address);
    // should reverted because of invalid target, value and data
    await expect(ZDAOChef.connect(userA).executeProposal(zDAOId, proposalId)).to
      .be.not.reverted;
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

    await addNewDAO(zNAOwner, 1);

    const zDAOId = 1;
    const proposalId = 1;

    await createProposal(userA, zDAOId);
    await increaseTime(zDAOConfig.duration);

    const rootZDAO = await ZDAOChef.zDAOs(zDAOId);
    const zDAO = (await ethers.getContractAt(
      "EthereumZDAO",
      rootZDAO,
      userA
    )) as EthereumZDAO;
    const zDAOInfo = await zDAO.zDAOInfo();

    const ethereumStateSender = await ZDAOChef.ethereumStateSender();
    await ZDAOChef.setVariable("ethereumStateSender", userA.address);

    // should execute proposal if proposal state is succeeded
    await expect(
      ZDAOChef.connect(userA).processMessageFromChild(
        encodeCalculateProposal({
          zDAOId,
          proposalId,
          voters: 1,
          yes: zDAOInfo.minimumTotalVotingTokens.toNumber(),
          no: 30,
        })
      )
    ).to.be.not.reverted;

    await ZDAOChef.setVariable("ethereumStateSender", ethereumStateSender);
    await ZDAOChef.connect(userA).executeProposal(zDAOId, proposalId);
  });
});
