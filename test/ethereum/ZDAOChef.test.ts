import {
  FakeContract,
  MockContract,
  MockContractFactory,
  smock,
} from "@defi-wonderland/smock";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import * as zns from "@zero-tech/zns-sdk";
import chai, { expect } from "chai";
import { ContractTransaction } from "ethers";
import { ethers } from "hardhat";
import ZDAOJson from "../../artifacts/contracts/ethereum/ZDAO.sol/ZDAO.json";
import {
  IERC20,
  IZNSHub,
  ZDAO,
  ZDAOChef,
  ZDAOChef__factory,
} from "../../types";

chai.use(smock.matchers);

describe("ZDAOChef", async function () {
  let owner: SignerWithAddress,
    zNAOwner: SignerWithAddress,
    zNAOwner2: SignerWithAddress,
    userA: SignerWithAddress;

  const zNA = "wilder.wheels";
  const zNAAsNumber = zns.domains.domainNameToId(zNA);
  const zNA2 = "wilder.cat";
  const zNAAsNumber2 = zns.domains.domainNameToId(zNA2);

  let ZNSHub: FakeContract<IZNSHub>,
    ZDAOChef: MockContract<ZDAOChef>,
    vToken: FakeContract<IERC20>;
  let gnosisSafe: string;
  const minAmount = 1000;

  beforeEach("init setup", async function () {
    [owner, zNAOwner, zNAOwner2, userA] = await ethers.getSigners();

    const ZDAOChefFactory = (await smock.mock<ZDAOChef__factory>(
      "ZDAOChef"
    )) as MockContractFactory<ZDAOChef__factory>;

    const znsHubAddress = await ethers.Wallet.createRandom().getAddress();
    ZDAOChef = (await ZDAOChefFactory.deploy()) as MockContract<ZDAOChef>;
    await ZDAOChef.__ZDAOChef_init(znsHubAddress);

    ZNSHub = (await smock.fake("IZNSHub", {
      address: znsHubAddress,
    })) as FakeContract<IZNSHub>;
    // make sure that `owner` is owner of zNA
    ZNSHub.ownerOf.whenCalledWith(zNAAsNumber).returns(zNAOwner.address);
    ZNSHub.ownerOf.whenCalledWith(zNAAsNumber2).returns(zNAOwner2.address);

    vToken = (await smock.fake("IERC20")) as FakeContract<IERC20>;

    gnosisSafe = await ethers.Wallet.createRandom().getAddress();
  });

  const addNewDAO = (user: SignerWithAddress): Promise<ContractTransaction> => {
    return ZDAOChef.connect(user).addNewDAO(zNAAsNumber, {
      id: 0,
      owner: zNAOwner.address,
      name: `${zNA}.dao`,
      gnosisSafe: gnosisSafe,
      token: vToken.address,
      amount: minAmount,
      destroyed: false,
    });
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
    const zDAO: ZDAO = (await ethers.getContractAt(
      ZDAOJson.abi,
      zDAORecord.zDAO,
      zNAOwner
    )) as ZDAO;
    expect(await zDAO.zDAOOwner()).to.be.equal(zNAOwner.address);
    // only one zNA association
    expect(zDAORecord.associatedzNAs.length).to.be.equal(1);
    expect(zDAORecord.associatedzNAs[0]).to.be.equal(zNAAsNumber);

    // list zDAOs
    const zDAORecords = await ZDAOChef.listzDAOs(1, 1);
    expect(zDAORecords.length).to.be.equal(1);
    expect(zDAORecords[0].id).to.be.equal(zDAORecord.id);
  });

  it("Only owner can remove DAO", async function () {
    await addNewDAO(zNAOwner);

    const daoId = 1;
    await expect(ZDAOChef.connect(userA).removeDAO(daoId)).to.be.revertedWith(
      "Invalid zDAO Owner"
    );
    // check if zDAO owner owner can remove DAO
    await expect(ZDAOChef.connect(zNAOwner).removeDAO(daoId)).to.be.not
      .reverted;

    expect(await ZDAOChef.numberOfzDAOs()).to.be.equal(0);
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
});
