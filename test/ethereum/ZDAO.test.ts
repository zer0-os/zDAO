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
  IERC20Upgradeable,
  IZNSHub,
  EtherZDAOChef__factory,
  EtherZDAO,
  EtherZDAOChef,
  ICheckpointManager,
  IFxStateSender,
} from "../../types";

chai.use(smock.matchers);

describe("ZDAO", async function () {
  let owner: SignerWithAddress,
    zNAOwner: SignerWithAddress,
    userA: SignerWithAddress,
    userB: SignerWithAddress;

  const zNA = "wilder.wheels";
  const zNAAsNumber = zns.domains.domainNameToId(zNA);

  let zDAO: EtherZDAO, vToken: FakeContract<IERC20Upgradeable>, zDAOInfo: any;
  let gnosisSafe: string;
  const minAmount = BigNumber.from("10000");
  const minPeriod = 30; // unit in seconds
  const threshold = 5000; // 100% percent in 10000

  beforeEach("init setup", async function () {
    [owner, zNAOwner, userA, userB] = await ethers.getSigners();

    const ZDAOChefFactory = (await smock.mock<EtherZDAOChef__factory>(
      "EtherZDAOChef"
    )) as MockContractFactory<EtherZDAOChef__factory>;
    const ZDAOFactory = await ethers.getContractFactory("EtherZDAO");
    const zDAOBase = await ZDAOFactory.deploy();

    const znsHubAddress = await ethers.Wallet.createRandom().getAddress();
    const checkPointManager = (await smock.fake(
      "ICheckpointManager"
    )) as FakeContract<ICheckpointManager>;
    const fxRoot = (await smock.fake(
      "IFxStateSender"
    )) as FakeContract<IFxStateSender>;

    const ZDAOChef =
      (await ZDAOChefFactory.deploy()) as MockContract<EtherZDAOChef>;
    await ZDAOChef.__ZDAOChef_init(
      znsHubAddress,
      zDAOBase.address,
      checkPointManager.address,
      fxRoot.address
    );

    const ZNSHub = (await smock.fake("IZNSHub", {
      address: znsHubAddress,
    })) as FakeContract<IZNSHub>;
    // make sure that `owner` is owner of zNA
    ZNSHub.ownerOf.whenCalledWith(zNAAsNumber).returns(zNAOwner.address);

    vToken = (await smock.fake(
      "IERC20Upgradeable"
    )) as FakeContract<IERC20Upgradeable>;

    // add new DAO by default
    gnosisSafe = await ethers.Wallet.createRandom().getAddress();
    await ZDAOChef.connect(zNAOwner).addNewDAO(zNAAsNumber, {
      name: `${zNA}.dao`,
      gnosisSafe: gnosisSafe,
      token: vToken.address,
      amount: minAmount,
      minPeriod: minPeriod,
      threshold: threshold,
    });

    const ZDAORecord = await ZDAOChef.getzDaoByZNA(zNAAsNumber);
    zDAO = (await ethers.getContractAt(
      ZDAOJson.abi,
      ZDAORecord.zDAO,
      zNAOwner
    )) as EtherZDAO;

    zDAOInfo = await zDAO.zDAOInfo();
  });

  it("Check zDAO information", async function () {
    expect(zDAOInfo.zDAOId).to.be.equal(1);
    expect(zDAOInfo.owner).to.be.equal(zNAOwner.address);
    expect(zDAOInfo.name).to.be.equal(`${zNA}.dao`);
    expect(zDAOInfo.gnosisSafe).to.be.equal(gnosisSafe);
    expect(zDAOInfo.token).to.be.equal(vToken.address);
    expect(zDAOInfo.amount.toString()).to.be.equal(minAmount.toString());
    expect(zDAOInfo.destroyed).to.be.equal(false);
  });

  const createProposal = async (
    user: SignerWithAddress,
    blocks = 30
  ): Promise<ContractTransaction> => {
    const blockNumber = await ethers.provider.getBlockNumber();
    const blockTime = 13;
    const startTimestamp = blockNumber * blockTime;
    const endTimestamp = startTimestamp + (blockNumber + blocks) * blockTime;

    return zDAO.connect(user).createProposal(
      startTimestamp,
      endTimestamp,
      vToken.address,
      minAmount.toString(),
      "0x0170171c23281b16a3c58934162488ad6d039df686eca806f21eba0cebd03486" // random byte32 string
    );
  };

  it("Only valid token holder can create proposal", async function () {
    await expect(createProposal(userA)).to.be.revertedWith(
      "Not a valid token holder"
    );

    vToken.balanceOf.whenCalledWith(userA.address).returns(minAmount);
    await expect(createProposal(userA)).to.be.not.reverted;

    expect(await zDAO.numberOfProposals()).to.be.equal(1);

    const proposals = await zDAO.listProposals(1, 1);
    expect(proposals.length).to.be.equal(1);
    expect(proposals[0].createdBy).to.be.equal(userA.address);
    expect(proposals[0].token).to.be.equal(vToken.address);
  });

  it("Should be callable by zDAO owner", async function () {
    await expect(
      zDAO.connect(userB).setVotingToken(vToken.address, minAmount.toString())
    ).to.be.revertedWith("Not a zDAO Owner");
    await expect(
      zDAO
        .connect(zNAOwner)
        .setVotingToken(vToken.address, minAmount.toString())
    ).to.be.not.reverted;
  });
});
