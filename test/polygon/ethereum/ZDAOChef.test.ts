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
import { PlatformType } from "../../../scripts/shared/config";
import {
  EthereumZDAO,
  EthereumZDAOChef,
  EthereumZDAOChef__factory,
  IERC20Upgradeable,
  IZDAOModule,
  IZDAOModule__factory,
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
    zDAOChef: MockContract<EthereumZDAOChef>,
    zDAOModule: FakeContract<IZDAOModule>,
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
    zDAOChef =
      (await ZDAOChefFactory.deploy()) as MockContract<EthereumZDAOChef>;
    zDAOModule = await smock.fake("IZDAOModule") as FakeContract<IZDAOModule>;
    await zDAOChef.__ZDAOChef_init(
      zDAORegistry,
      ethereumStateSender.address,
      zDAOModule.address,
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
      votingDelay: 0,
      votingThreshold: 5001, // 50.01%
      minimumVotingParticipants: 1,
      minimumTotalVotingTokens: minimumTotalVotingTokens,
      isRelativeMajority: true,
    };

    proposalConfig = {
      choices: ["Approve", "Deny", "Absence"],
      ipfs: "0x0170171c23281b16a3c58934162488ad6d039df686eca806f21eba0cebd03486", // random byte32 string
    };
  });

  const addNewDAO = async (
    user: SignerWithAddress,
    zDAOId: number
  ): Promise<ContractTransaction> => {
    await zDAOChef.setVariable("zDAORegistry", user.address);
    return zDAOChef.connect(user).addNewZDAO(
      zDAOId,
      zNAAsNumber,
      user.address,
      gnosisSafe,
      ethers.utils.defaultAbiCoder.encode(
        [
          "address",
          "uint256",
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
          zDAOConfig.votingDelay,
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
    return zDAOChef.connect(user).createProposal(
      daoId,
      proposalConfig.choices,
      proposalConfig.ipfs
    );
  };

  it("Should not add same DAO twice", async function () {
    await addNewDAO(zNAOwner, 1);

    await expect(addNewDAO(zNAOwner, 1)).to.be.reverted;
  });

  it("Should modify Gnosis Safe and voting token", async function () {
    await addNewDAO(zNAOwner, 1);

    const newGnosisSafe = await ethers.Wallet.createRandom().getAddress();

    await expect(
      zDAOChef.connect(zNAOwner).modifyZDAO(
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
      votes: [70, 20, 10],
    });

    await zDAOChef.setVariable("ethereumStateSender", userA.address);
    await expect(zDAOChef.connect(userA).processMessageFromChild(message)).to.be
      .not.reverted;

    const rootZDAO = await zDAOChef.zDAOs(zDAOId);
    const zDAO = (await ethers.getContractAt(
      "EthereumZDAO",
      rootZDAO,
      userA
    )) as EthereumZDAO;

    const proposal = await zDAO.getProposalById(proposalId);
    expect(proposal.votes[0].toNumber()).to.be.equal(70);
    expect(proposal.votes[1].toNumber()).to.be.equal(20);
    expect(proposal.votes[2].toNumber()).to.be.equal(10);
  });

  it("Should not execute a failed proposal", async function () {
    await addNewDAO(zNAOwner, 1);

    const zDAOId = 1;
    vToken.balanceOf.whenCalledWith(userA.address).returns(zDAOConfig.amount);
    await expect(createProposal(userA, zDAOId)).to.be.not.reverted;

    await increaseTime(30);

    const rootZDAO = await zDAOChef.zDAOs(zDAOId);
    const zDAO = (await ethers.getContractAt(
      "EthereumZDAO",
      rootZDAO,
      userA
    )) as EthereumZDAO;
    const zDAOInfo = await zDAO.zDAOInfo();
    const proposalId = 1;

    await zDAOChef.setVariable("ethereumStateSender", userA.address);

    // should not execute proposal if proposal state is failed
    await expect(
      zDAOChef.connect(userA).processMessageFromChild(
        encodeCalculateProposal({
          zDAOId,
          proposalId,
          voters: 1,
          votes: [
            zDAOInfo.minimumTotalVotingTokens.toNumber(),
            zDAOInfo.minimumTotalVotingTokens.toNumber() + 1,
            zDAOInfo.minimumTotalVotingTokens.toNumber() + 2,
          ],
        })
      )
    ).to.be.not.reverted;

    const state = await zDAO.state(proposalId);
    expect(state).to.be.equal(4); // ProposalState.Closed
  });

  it("Should execute a succeeded proposal", async function () {
    await addNewDAO(zNAOwner, 1);

    const zDAOId = 1;
    vToken.balanceOf.whenCalledWith(userA.address).returns(zDAOConfig.amount);
    await expect(createProposal(userA, zDAOId)).to.be.not.reverted;

    await increaseTime(30);

    const rootZDAO = await zDAOChef.zDAOs(zDAOId);
    const zDAO = (await ethers.getContractAt(
      "EthereumZDAO",
      rootZDAO,
      userA
    )) as EthereumZDAO;
    const zDAOInfo = await zDAO.zDAOInfo();
    const proposalId = 1;

    await zDAOChef.setVariable("ethereumStateSender", userA.address);

    // should execute proposal if proposal state is succeeded
    await expect(
      zDAOChef.connect(userA).processMessageFromChild(
        encodeCalculateProposal({
          zDAOId,
          proposalId,
          voters: 1,
          votes: [zDAOInfo.minimumTotalVotingTokens.toNumber(), 0, 0],
        })
      )
    ).to.be.not.reverted;

    const state = await zDAO.state(proposalId);
    expect(state).to.be.equal(5); // ProposalState.AwaitingExecution
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

    const rootZDAO = await zDAOChef.zDAOs(zDAOId);
    const zDAO = (await ethers.getContractAt(
      "EthereumZDAO",
      rootZDAO,
      userA
    )) as EthereumZDAO;
    const zDAOInfo = await zDAO.zDAOInfo();

    const ethereumStateSender = await zDAOChef.ethereumStateSender();
    await zDAOChef.setVariable("ethereumStateSender", userA.address);

    // should execute proposal if proposal state is succeeded
    await expect(
      zDAOChef.connect(userA).processMessageFromChild(
        encodeCalculateProposal({
          zDAOId,
          proposalId,
          voters: 1,
          votes: [zDAOInfo.minimumTotalVotingTokens.toNumber(), 30, 0],
        })
      )
    ).to.be.not.reverted;

    zDAOModule.isProposalExecuted.whenCalledWith(PlatformType.Polygon, proposalId).returns(true);

    const state = await zDAO.state(proposalId);
    expect(state).to.be.equal(3); // ProposalState.Executed
  });
});
