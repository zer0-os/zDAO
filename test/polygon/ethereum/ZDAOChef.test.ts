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
  EthereumZDAO,
  EthereumZDAOChef,
  EthereumZDAOChef__factory,
  IERC20Upgradeable,
} from "../../../types";
import { IEthereumStateSender } from "../../../types/IEthereumStateSender";
import { encodeCalculateProposal } from "../../shared/messagePack";
import { ProposalConfig, ZDAOConfig } from "../../shared/types";
import { increaseTime, mineToBlock } from "../../shared/utilities";

chai.use(smock.matchers);

describe("ZDAOChef", async function () {
  let userA: SignerWithAddress;

  let ethereumStateSender: FakeContract<IEthereumStateSender>,
    zDAOChef: MockContract<EthereumZDAOChef>,
    vToken: FakeContract<IERC20Upgradeable>;

  let gnosisSafe: string,
    zDAOConfig: ZDAOConfig,
    proposalConfig: ProposalConfig;

  beforeEach("init setup", async function () {
    [, userA] = await ethers.getSigners();

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
    await zDAOChef.__ZDAOChef_init(
      zDAORegistry,
      ethereumStateSender.address,
      zDAOBase.address
    );

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
    return zDAOChef
      .connect(user)
      .addNewZDAO(
        zDAOId,
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
    return zDAOChef
      .connect(user)
      .createProposal(daoId, proposalConfig.choices, proposalConfig.ipfs);
  };

  it("Should not add same DAO twice", async function () {
    await addNewDAO(userA, 1);

    await expect(addNewDAO(userA, 1)).to.be.reverted;
  });

  it("Should modify Gnosis Safe and voting token", async function () {
    await addNewDAO(userA, 1);

    const newGnosisSafe = await ethers.Wallet.createRandom().getAddress();

    await expect(
      zDAOChef
        .connect(userA)
        .modifyZDAO(
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
    await addNewDAO(userA, 1);

    const zDAOId = 1;
    vToken.balanceOf.whenCalledWith(userA.address).returns(zDAOConfig.amount);

    await createProposal(userA, zDAOId);
    await expect(createProposal(userA, zDAOId)).to.be.not.reverted;
  });

  it("Should calculate voting result", async function () {
    await addNewDAO(userA, 1);

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
    await addNewDAO(userA, 1);

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
    expect(state).to.be.equal(3); // ProposalState.Closed
  });

  it("Should execute a succeeded proposal", async function () {
    await addNewDAO(userA, 1);

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
    expect(state).to.be.equal(3); // ProposalState.Closed
  });
});
