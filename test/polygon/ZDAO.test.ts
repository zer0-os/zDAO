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
  PolyZDAO,
  PolyZDAO__factory,
  IChildTunnel,
} from "../../types";
import { Staking__factory } from "../../types/factories/Staking__factory";
import { Staking } from "../../types/Staking";
import { PolyProposalConfig, PolyZDAOConfig } from "../shared/types";
import { increaseTime, now } from "../shared/utilities";

chai.use(smock.matchers);

describe("ZDAO", async function () {
  let owner: SignerWithAddress,
    userA: SignerWithAddress,
    userB: SignerWithAddress,
    userC: SignerWithAddress;

  let childTunnel: FakeContract<IChildTunnel>,
    staking: MockContract<Staking>,
    zDAO: MockContract<PolyZDAO>,
    vToken: FakeContract<IERC20Upgradeable>,
    vPolyToken: FakeContract<IERC20Upgradeable>,
    zDAOInfo: any;

  let zDAOConfig: PolyZDAOConfig, proposalConfig: PolyProposalConfig;

  beforeEach("init setup", async function () {
    [owner, userA, userB, userC] = await ethers.getSigners();

    const ZDAOFactory = (await smock.mock<PolyZDAO__factory>(
      "PolyZDAO"
    )) as MockContractFactory<PolyZDAO__factory>;
    zDAO = (await ZDAOFactory.deploy()) as MockContract<PolyZDAO>;

    childTunnel = (await smock.fake(
      "IChildTunnel"
    )) as FakeContract<IChildTunnel>;

    const StakingFactory = (await smock.mock<Staking__factory>(
      "Staking"
    )) as MockContractFactory<Staking__factory>;
    staking = (await StakingFactory.deploy()) as MockContract<Staking>;
    await staking.__Staking_init();

    vToken = (await smock.fake(
      "IERC20Upgradeable"
    )) as FakeContract<IERC20Upgradeable>;

    // vPolyToken is mapped token on Polygon from vToken
    vPolyToken = (await smock.fake(
      "IERC20Upgradeable"
    )) as FakeContract<IERC20Upgradeable>;

    const zDAOId = 1;
    const minAmount = BigNumber.from("10000");
    const minPeriod = 30; // unit in seconds

    zDAOConfig = {
      zDAOId,
      mappedToken: vPolyToken.address,
      isRelativeMajority: false,
      threshold: 5000,
    };

    await zDAO.__ZDAO_init(
      childTunnel.address,
      staking.address,
      zDAOConfig.zDAOId,
      zDAOConfig.mappedToken,
      zDAOConfig.isRelativeMajority,
      zDAOConfig.threshold
    );

    await staking.grantRole(await staking.LOCKER_ROLE(), zDAO.address);

    vToken = (await smock.fake(
      "IERC20Upgradeable"
    )) as FakeContract<IERC20Upgradeable>;

    zDAOInfo = await zDAO.zDAOInfo();

    proposalConfig = {
      proposalId: 1,
      startTimestamp: await now(),
      endTimestamp: (await now()) + minPeriod,
    };
  });

  it("Check zDAO information", async function () {
    expect(zDAOInfo.zDAOId).to.be.equal(zDAOConfig.zDAOId);
    expect(zDAOInfo.mappedToken).to.be.equal(zDAOConfig.mappedToken);
    expect(zDAOInfo.isRelativeMajority).to.be.equal(
      zDAOConfig.isRelativeMajority
    );
    expect(zDAOInfo.threshold.toNumber()).to.be.equal(zDAOConfig.threshold);
    expect(zDAOInfo.snapshot).to.be.gt(0);
    expect(zDAOInfo.destroyed).to.be.equal(false);
  });

  const createProposal = async (
    user: SignerWithAddress
  ): Promise<ContractTransaction> => {
    return zDAO
      .connect(user)
      .createProposal(
        proposalConfig.proposalId,
        proposalConfig.startTimestamp,
        proposalConfig.endTimestamp
      );
  };

  it("Proposal can be created by child tunnel when it receives message from Ethereum", async function () {
    // check if user can create proposal
    await expect(createProposal(userA)).to.be.revertedWith("Not a ZDAOChef");
    // make sure only child tunnel can call setVoteResult function
    await zDAO.setVariable("childTunnel", userA.address);
    await expect(createProposal(userA)).to.be.not.reverted;

    expect(await zDAO.numberOfProposals()).to.be.equal(1);

    const proposals = await zDAO.listProposals(1, 1);
    expect(proposals.length).to.be.equal(1);
  });

  it("Any staker should be able to vote on proposal", async function () {
    await zDAO.setVariable("childTunnel", userA.address);
    await createProposal(userA);

    staking.userStaked
      .whenCalledWith(userB.address, zDAOConfig.mappedToken)
      .returns(BigNumber.from(100000));

    const proposalId = 1;
    const choice = 1; // yes

    await zDAO.connect(userB).vote(proposalId, choice);

    await expect(zDAO.connect(userB).vote(proposalId, choice)).to.be.not
      .reverted;

    // check if voter can change his choice
    await expect(zDAO.connect(userB).vote(proposalId, choice + 1)).to.be.not
      .reverted;

    const lastChoice = await zDAO.getVoterChoice(proposalId, userB.address);
    expect(lastChoice).to.be.equal(choice + 1);
  });

  it("Only can collect voting result after proposal ends", async function () {
    await zDAO.setVariable("childTunnel", userA.address);
    await createProposal(userA);

    staking.userStaked
      .whenCalledWith(userA.address, zDAOConfig.mappedToken)
      .returns(BigNumber.from(100000));

    staking.userStaked
      .whenCalledWith(userB.address, zDAOConfig.mappedToken)
      .returns(BigNumber.from(100000));

    staking.userStaked
      .whenCalledWith(userC.address, zDAOConfig.mappedToken)
      .returns(BigNumber.from(100000));

    const proposalId = 1;
    const choice = 1; // yes
    await zDAO.connect(userA).vote(proposalId, choice);
    await zDAO.connect(userB).vote(proposalId, choice);
    await zDAO.connect(userC).vote(proposalId, choice + 1);

    await expect(
      zDAO.connect(userC).collectResult(proposalId)
    ).to.be.revertedWith("Not valid for collecting result");

    // mint to the end of proposal
    await increaseTime(
      proposalConfig.endTimestamp - proposalConfig.startTimestamp
    );

    zDAO.setVariable("childTunnel", childTunnel.address);
    await expect(zDAO.connect(userC).collectResult(proposalId)).to.be.not
      .reverted;
  });
});
