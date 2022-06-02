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
  MockTokenUpgradeable,
  MockTokenUpgradeable__factory,
  PolyZDAO,
  PolyZDAO__factory,
} from "../../types";
import { Staking__factory } from "../../types/factories/Staking__factory";
import { Staking } from "../../types/Staking";
import { PolyProposalConfig, PolyZDAOConfig } from "../shared/types";
import { increaseTime, mineToBlock, now } from "../shared/utilities";

chai.use(smock.matchers);

describe("ZDAO", async function () {
  let owner: SignerWithAddress,
    zDAOChef: SignerWithAddress,
    userA: SignerWithAddress,
    userB: SignerWithAddress,
    userC: SignerWithAddress;

  let staking: MockContract<Staking>,
    zDAO: MockContract<PolyZDAO>,
    vToken: MockContract<MockTokenUpgradeable>,
    zDAOInfo: any;

  let zDAOConfig: PolyZDAOConfig, proposalConfig: PolyProposalConfig;

  let BIG_POW: BigNumber;

  beforeEach("init setup", async function () {
    [owner, zDAOChef, userA, userB, userC] = await ethers.getSigners();

    const ZDAOFactory = (await smock.mock<PolyZDAO__factory>(
      "PolyZDAO"
    )) as MockContractFactory<PolyZDAO__factory>;
    zDAO = (await ZDAOFactory.deploy()) as MockContract<PolyZDAO>;

    const StakingFactory = (await smock.mock<Staking__factory>(
      "Staking"
    )) as MockContractFactory<Staking__factory>;
    staking = (await StakingFactory.deploy()) as MockContract<Staking>;
    await staking.__Staking_init();

    const VotingTokenFactory = (await smock.mock<MockTokenUpgradeable__factory>(
      "MockTokenUpgradeable"
    )) as MockContractFactory<MockTokenUpgradeable__factory>;
    vToken =
      (await VotingTokenFactory.deploy()) as MockContract<MockTokenUpgradeable>;
    await vToken.__MockTokenUpgradeable_init("vToken", "VT");

    BIG_POW = BigNumber.from(10).pow(18);

    const zDAOId = 1;
    const minAmount = BigNumber.from("10000");
    const minDuration = 300; // unit in seconds

    zDAOConfig = {
      zDAOId,
      duration: minDuration,
    };

    await zDAO.__ZDAO_init(
      zDAOChef.address,
      staking.address,
      zDAOConfig.zDAOId,
      zDAOConfig.duration,
      vToken.address
    );

    zDAOInfo = await zDAO.zDAOInfo();

    proposalConfig = {
      proposalId: 1,
      startTimestamp: await now(),
    };

    await vToken.mintFor(userA.address, BigNumber.from(10000000).mul(BIG_POW));
    await vToken.mintFor(userB.address, BigNumber.from(10000000).mul(BIG_POW));
    await vToken.mintFor(userC.address, BigNumber.from(10000000).mul(BIG_POW));

    await vToken
      .connect(userA)
      .approve(staking.address, ethers.constants.MaxUint256);
    await vToken
      .connect(userB)
      .approve(staking.address, ethers.constants.MaxUint256);
    await vToken
      .connect(userC)
      .approve(staking.address, ethers.constants.MaxUint256);
  });

  it("Check zDAO information", async function () {
    expect(zDAOInfo.zDAOId).to.be.equal(zDAOConfig.zDAOId);
    expect(zDAOInfo.duration).to.be.equal(zDAOConfig.duration);
    expect(zDAOInfo.snapshot).to.be.gt(0);
    expect(zDAOInfo.destroyed).to.be.equal(false);
  });

  const createProposal = async (
    userA?: SignerWithAddress
  ): Promise<ContractTransaction> => {
    return zDAO
      .connect(userA ?? zDAOChef)
      .createProposal(proposalConfig.proposalId, proposalConfig.startTimestamp);
  };

  it("Proposal can be created by child tunnel when it receives message from Ethereum", async function () {
    // check if user can create proposal
    await expect(createProposal(userA)).to.be.revertedWith("Not a ZDAOChef");
    await expect(createProposal()).to.be.not.reverted;

    expect(await zDAO.numberOfProposals()).to.be.equal(1);

    const proposals = await zDAO.listProposals(0, 1);
    expect(proposals.length).to.be.equal(1);
  });

  it("Any staker should be able to vote on proposal", async function () {
    await staking
      .connect(userB)
      .stakeERC20(vToken.address, BigNumber.from(1000).mul(BIG_POW));
    await mineToBlock(1);

    await createProposal();
    await mineToBlock(1);

    const proposalId = 1;
    const choice = 1; // yes

    await zDAO.connect(zDAOChef).vote(proposalId, userB.address, choice);

    await expect(zDAO.connect(zDAOChef).vote(proposalId, userB.address, choice))
      .to.be.not.reverted;

    // check if voter can change his choice
    await expect(
      zDAO.connect(zDAOChef).vote(proposalId, userB.address, choice + 1)
    ).to.be.not.reverted;

    const lastChoice = await zDAO.choiceOfVoter(proposalId, userB.address);
    expect(lastChoice).to.be.equal(choice + 1);
  });

  it("Only can calculate voting result after proposal ends", async function () {
    await staking
      .connect(userA)
      .stakeERC20(vToken.address, BigNumber.from(1000).mul(BIG_POW));
    await staking
      .connect(userB)
      .stakeERC20(vToken.address, BigNumber.from(2000).mul(BIG_POW));
    await staking
      .connect(userC)
      .stakeERC20(vToken.address, BigNumber.from(3000).mul(BIG_POW));
    await mineToBlock(1);

    await createProposal();
    await mineToBlock(1);

    const proposalId = 1;

    const choice = 1; // yes
    await zDAO.connect(zDAOChef).vote(proposalId, userA.address, choice);
    await zDAO.connect(zDAOChef).vote(proposalId, userB.address, choice);
    await zDAO.connect(zDAOChef).vote(proposalId, userC.address, choice + 1);

    await expect(
      zDAO.connect(zDAOChef).calculateProposal(proposalId)
    ).to.be.revertedWith("Not a valid proposal");

    // mint to the end of proposal
    await increaseTime(zDAOConfig.duration);

    await expect(zDAO.connect(zDAOChef).calculateProposal(proposalId)).to.be.not
      .reverted;

    const {
      voters: numberOfVoters,
      yes,
      no,
    } = await zDAO.votesResultOfProposal(proposalId);
    const { voters, choices, votes } = await zDAO.listVoters(
      proposalId,
      0,
      numberOfVoters
    );
    expect(voters[0]).to.be.equal(userA.address);
    expect(voters[1]).to.be.equal(userB.address);
    expect(voters[2]).to.be.equal(userC.address);

    expect(choices[0].toNumber()).to.be.equal(choice);
    expect(choices[1].toNumber()).to.be.equal(choice);
    expect(choices[2].toNumber()).to.be.equal(choice + 1);

    expect(votes[0].toNumber()).to.be.equal(1000);
    expect(votes[1].toNumber()).to.be.equal(2000);
    expect(votes[2].toNumber()).to.be.equal(3000);
  });
});
