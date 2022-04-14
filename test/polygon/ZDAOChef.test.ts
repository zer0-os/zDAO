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
  IERC20Upgradeable,
} from "../../types";
import { Registry__factory } from "../../types/factories/Registry__factory";
import { Staking__factory } from "../../types/factories/Staking__factory";
import { Registry } from "../../types/Registry";
import { Staking } from "../../types/Staking";
import {
  CreateProposalPack,
  CreateZDAOPack,
  encodeCreateProposal,
  encodeCreateZDAO,
  encodeDeleteZDAO,
} from "../shared/messagePack";
import { now } from "../shared/utilities";

chai.use(smock.matchers);

describe("ZDAOChef", async function () {
  let owner: SignerWithAddress,
    fxChild: SignerWithAddress,
    zDAOOwner: SignerWithAddress,
    userA: SignerWithAddress;

  let staking: MockContract<Staking>,
    registry: MockContract<Registry>,
    ZDAOChef: MockContract<PolyZDAOChef>,
    vToken: FakeContract<IERC20Upgradeable>,
    vPolyToken: FakeContract<IERC20Upgradeable>;

  let zDAOPack: CreateZDAOPack, proposalPack: CreateProposalPack;

  beforeEach("init setup", async function () {
    [owner, fxChild, zDAOOwner, userA] = await ethers.getSigners();

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

    const RegistryFactory = (await smock.mock<Registry__factory>(
      "Registry"
    )) as MockContractFactory<Registry__factory>;
    registry = (await RegistryFactory.deploy()) as MockContract<Registry>;
    await registry.__Registry_init();

    ZDAOChef = (await ZDAOChefFactory.deploy()) as MockContract<PolyZDAOChef>;
    await ZDAOChef.__ZDAOChef_init(
      staking.address,
      registry.address,
      zDAOBase.address,
      fxChild.address
    );

    // remember: transfer admin role to zDAOChef
    await staking.grantRole(
      await staking.DEFAULT_ADMIN_ROLE(),
      ZDAOChef.address
    );

    vToken = (await smock.fake(
      "IERC20Upgradeable"
    )) as FakeContract<IERC20Upgradeable>;

    // vPolyToken is mapped token on Polygon from vToken
    vPolyToken = (await smock.fake(
      "IERC20Upgradeable"
    )) as FakeContract<IERC20Upgradeable>;

    // remember: mapping tokens between Ethereum and Polygon
    registry.rootToChildToken
      .whenCalledWith(vToken.address)
      .returns(vPolyToken.address);
    registry.childToRootToken
      .whenCalledWith(vPolyToken.address)
      .returns(vToken.address);

    const minAmount = BigNumber.from("10000");
    const minPeriod = 300; // unit in seconds
    const threshold = 5000; // 100% percent in 10000

    zDAOPack = {
      lastZDAOId: 1,
      name: "Mock ZDAO",
      zDAOOwner: zDAOOwner.address,
      token: vToken.address, // token address on Ethereum
      isRelativeMajority: true,
      threshold: threshold,
    };

    proposalPack = {
      zDAOId: 1,
      proposalId: 1,
      createdBy: userA.address,
      startTimestamp: await now(),
      endTimestamp: (await now()) + minPeriod,
      token: vToken.address, // token address on Ethereum
      amount: minAmount.toNumber(),
      ipfs: "0x0170171c23281b16a3c58934162488ad6d039df686eca806f21eba0cebd03486", // random byte32 string
    };
  });

  const createZDAO = () => {
    const message = encodeCreateZDAO(zDAOPack);

    return ZDAOChef.connect(fxChild).processMessageFromRoot(
      1,
      userA.address,
      message
    );
  };

  const deleteZDAO = () => {
    const message = encodeDeleteZDAO({
      zDAOId: zDAOPack.lastZDAOId,
    });

    return ZDAOChef.connect(fxChild).processMessageFromRoot(
      1,
      userA.address,
      message
    );
  };

  const createProposal = () => {
    const messageProposal = encodeCreateProposal(proposalPack);

    return ZDAOChef.connect(fxChild).processMessageFromRoot(
      1, // stateId
      userA.address, // rootMessageSender
      messageProposal
    );
  };

  it("Should be able to create zDAO from the message", async function () {
    await expect(createZDAO()).to.be.not.reverted;

    const zDAOAddr = await ZDAOChef.getzDAOById(1);
    const zDAO = (await ethers.getContractAt(
      ZDAOJson.abi,
      zDAOAddr,
      zDAOOwner
    )) as PolyZDAO;

    const zDAOInfo = await zDAO.zDAOInfo();
    expect(zDAOInfo.zDAOId).to.be.equal(zDAOPack.lastZDAOId);
    expect(zDAOInfo.name).to.be.equal(zDAOPack.name);
    expect(zDAOInfo.owner).to.be.equal(zDAOPack.zDAOOwner);
    expect(zDAOInfo.token).to.be.equal(zDAOPack.token);
    // mapped token
    expect(zDAOInfo.isRelativeMajority).to.be.equal(
      zDAOPack.isRelativeMajority
    );
    expect(zDAOInfo.threshold).to.be.equal(zDAOPack.threshold);
  });

  it("Should not add same DAO twice", async function () {
    await createZDAO();

    // check if revert when add same
    await expect(createZDAO()).to.be.revertedWith("zDAO was already created");
  });

  it("Should list zDAOs", async function () {
    await createZDAO();

    // already created one DAO
    expect(await ZDAOChef.numberOfzDAOs()).to.be.equal(1);

    const daoId = 1;
    const zDAOAddr = await ZDAOChef.getzDAOById(daoId);

    // list zDAOs
    const zDAOAddrs = await ZDAOChef.listzDAOs(1, 1);
    expect(zDAOAddrs.length).to.be.equal(1);
    expect(zDAOAddrs[0]).to.be.equal(zDAOAddr);
  });

  it("Should be able to delete zDAO from the message", async function () {
    await createZDAO();

    await expect(deleteZDAO()).to.be.not.reverted;

    // check if zDAO is destroyed
    const zDAOAddr = await ZDAOChef.getzDAOById(1);
    const zDAO = (await ethers.getContractAt(
      ZDAOJson.abi,
      zDAOAddr,
      zDAOOwner
    )) as PolyZDAO;

    expect(await zDAO.destroyed()).to.be.equal(true);

    // check if revert to create proposal on deleted zDAO
    await expect(createProposal()).to.be.revertedWith("Already destroyed");
  });

  it("Should be able to create proposal from the message", async function () {
    // check if failed to create proposal without zDAO
    await expect(createProposal()).to.be.revertedWith("Not created zDAO yet");

    // create zDAO first
    await createZDAO();

    const zDAOAddr = await ZDAOChef.getzDAOById(1);
    const zDAO = (await ethers.getContractAt(
      ZDAOJson.abi,
      zDAOAddr,
      zDAOOwner
    )) as PolyZDAO;

    // try to create proposal again
    await expect(createProposal()).to.be.not.reverted;

    // check if revert when add same
    await expect(createProposal()).to.be.revertedWith(
      "Proposal was already created"
    );

    expect(await zDAO.numberOfProposals()).to.be.equal(1);
    const proposals = await zDAO.listProposals(1, 1);

    expect(proposals[0].proposalId).to.be.equal(proposalPack.proposalId);
    expect(proposals[0].createdBy).to.be.equal(proposalPack.createdBy);
    expect(proposals[0].startTimestamp).to.be.equal(
      proposalPack.startTimestamp
    );
    expect(proposals[0].endTimestamp).to.be.equal(proposalPack.endTimestamp);
    expect(proposals[0].ipfs).to.be.equal(proposalPack.ipfs);
    expect(proposals[0].token).to.be.equal(proposalPack.token);
    expect(proposals[0].amount.toString()).to.be.equal(
      proposalPack.amount.toString()
    );
    expect(proposals[0].state).to.be.equal(0); // Active state
  });
});
