import { FakeContract, MockContract, smock } from "@defi-wonderland/smock";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import {
  IZNSHub,
  ZDAORegistry,
  ZDAORegistryV2,
  ZDAORegistryV2__factory,
  ZDAORegistry__factory,
} from "../types";
import { restoreSnapshot, takeSnapshot } from "./helpers";

describe("zDAORegistry", async () => {
  let accounts: SignerWithAddress[],
    deployer: SignerWithAddress,
    zNAOwner: SignerWithAddress,
    userA: SignerWithAddress;

  let zNSHub: FakeContract<IZNSHub>, zDAORegistry: ZDAORegistry, zDAORegistryV2: ZDAORegistryV2;

  let lastSnapshotId: string;

  const wilder_beasts = ethers.BigNumber.from(
    "0x290422f1f79e710c65e3a72fe8dddc0691bb638c865f5061a5e639cf244ee5ed"
  );
  const wilder_kicks = ethers.BigNumber.from(
    "0x79e5bdb3f024a898df02a5472e6fc5373e6a3c5f65317f58223a579d518378df"
  );
  const ENS = "zdao-test.eth",
    ENS2 = "zdao-test2.eth",
    gnosisSafe = "0x73D44dEa3A3334aB2504443479aD531FfeD2d2D9",
    gnosisSafe2 = "0xAFAEa4937122C7BeEcD0210b28F54EA9bFaceef9",
    token = "0x5FbDB2315678afecb367f032d93F642f64180aa3";

  const deployZDAORegistry = async (deployer: SignerWithAddress) => {
    const zNSHub = (await smock.fake("IZNSHub")) as FakeContract<IZNSHub>;

    const zDAORegistryFactory = new ZDAORegistry__factory(deployer);
    const zDAORegistry = (await upgrades.deployProxy(zDAORegistryFactory, [
      zNSHub.address,
    ])) as ZDAORegistry;
    await zDAORegistry.deployed();

    return { zNSHub, zDAORegistry };
  };

  const upgradeToV2 = async (zDAORegistry: string) => {
    const zDAORegistryFactory = new ZDAORegistryV2__factory(deployer);
    const zDAORegistryV2 = (await upgrades.upgradeProxy(
      zDAORegistry,
      zDAORegistryFactory
    )) as ZDAORegistryV2;

    return { zDAORegistryV2 };
  };

  before(async () => {
    accounts = await ethers.getSigners();
    [deployer, zNAOwner, userA] = accounts;

    ({ zNSHub, zDAORegistry } = await deployZDAORegistry(deployer));
    zNSHub.ownerOf.reset();
  });

  beforeEach(async () => {
    lastSnapshotId = await takeSnapshot();
  });

  afterEach(async () => {
    await restoreSnapshot(lastSnapshotId);
  });

  describe("Deployment", async () => {
    it("Should set zNSHub", async () => {
      expect(await zDAORegistry.znsHub()).to.be.equal(zNSHub.address);
    });
  });

  describe("Add DAO", async () => {
    it("Should add new DAO", async () => {
      await expect(zDAORegistry.connect(deployer).addNewDAO(ENS, gnosisSafe)).to.be.not.reverted;
    });

    it("Should revert when add duplicated ENS name", async () => {
      await zDAORegistry.connect(deployer).addNewDAO(ENS, gnosisSafe);

      await expect(zDAORegistry.connect(deployer).addNewDAO(ENS, gnosisSafe2)).to.be.revertedWith(
        "ENS already has zDAO"
      );
    });

    it("Should not revert when add same gnosis safe address with different ENS name", async () => {
      await zDAORegistry.connect(deployer).addNewDAO(ENS, gnosisSafe);

      await expect(zDAORegistry.connect(deployer).addNewDAO(ENS2, gnosisSafe)).to.be.not.reverted;
    });
  });

  describe("zNA Association/Disassociation", async () => {
    beforeEach(async () => {
      await zDAORegistry.connect(deployer).addNewDAO(ENS, gnosisSafe);

      zNSHub.ownerOf.whenCalledWith(wilder_beasts).returns(zNAOwner.address);

      expect(await zDAORegistry.numberOfzDAOs()).to.be.equal(1);
    });

    describe("Association", async () => {
      it("Only zNA owner can associate zDAO and zNA", async () => {
        await expect(zDAORegistry.connect(zNAOwner).addZNAAssociation(1, wilder_beasts)).to.be.not
          .reverted;

        expect(await zDAORegistry.doeszDAOExistForzNA(wilder_beasts)).to.be.true;
      });

      it("Should revert when associate by non zNA owner", async () => {
        await expect(zDAORegistry.connect(userA).addZNAAssociation(1, wilder_beasts)).to.be
          .reverted;

        expect(await zDAORegistry.doeszDAOExistForzNA(wilder_beasts)).to.be.false;
      });
    });

    describe("Disassociation", async () => {
      beforeEach(async () => {
        await zDAORegistry.connect(zNAOwner).addZNAAssociation(1, wilder_beasts);
      });

      it("Only zNA owner can disassociate zDAO and zNA", async () => {
        await expect(zDAORegistry.connect(zNAOwner).removeZNAAssociation(1, wilder_beasts)).to.be
          .not.reverted;

        expect(await zDAORegistry.doeszDAOExistForzNA(wilder_beasts)).to.be.false;
      });

      it("Should revert when disassociate by non-zNA owner", async () => {
        await expect(zDAORegistry.connect(userA).removeZNAAssociation(1, wilder_beasts)).to.be
          .reverted;

        expect(await zDAORegistry.doeszDAOExistForzNA(wilder_beasts)).to.be.true;
      });

      it("Should revert if already disassociated", async () => {
        await expect(zDAORegistry.connect(zNAOwner).removeZNAAssociation(1, wilder_beasts)).to.be
          .not.reverted;

        await expect(
          zDAORegistry.connect(zNAOwner).removeZNAAssociation(1, wilder_beasts)
        ).to.be.revertedWith("zNA not associated");

        expect(await zDAORegistry.doeszDAOExistForzNA(wilder_beasts)).to.be.false;
      });
    });
  });

  describe("Upgradeability", async () => {
    beforeEach(async () => {
      await zDAORegistry.connect(deployer).addNewDAO(ENS, gnosisSafe);
      await zDAORegistry.connect(zNAOwner).addZNAAssociation(1, wilder_beasts);

      ({ zDAORegistryV2 } = await upgradeToV2(zDAORegistry.address));
      expect(zDAORegistryV2.address).to.be.equal(zDAORegistry.address);

      zNSHub.ownerOf.whenCalledWith(wilder_beasts).returns(zNAOwner.address);
      zNSHub.ownerOf.whenCalledWith(wilder_kicks).returns(zNAOwner.address);
    });

    it("Storage should be preserved", async () => {
      expect(await zDAORegistryV2.numberOfzDAOs()).to.be.equal(1);

      const zDAORecord = await zDAORegistryV2.getzDAOById(1);
      expect(zDAORecord.id).to.be.equal(1);
      expect(zDAORecord.ensSpace).to.be.equal(ENS);
      expect(zDAORecord.gnosisSafe).to.be.equal(gnosisSafe);
      expect(zDAORecord.destroyed).to.be.false;
      expect(zDAORecord.token).to.be.equal(ethers.constants.AddressZero);

      expect(await zDAORegistryV2.doeszDAOExistForzNA(wilder_beasts)).to.be.true;
      expect(await zDAORegistryV2.getzDAOIdForzNA(wilder_beasts)).to.be.equal(1);

      const zDAORecord2 = await zDAORegistryV2.getzDAOByENS(ENS);
      const zDAORecord3 = await zDAORegistryV2.getzDAOByzNA(wilder_beasts);

      for (let i = 0; i < zDAORecord.length; i++) {
        expect(zDAORecord[i].toString()).to.be.equal(zDAORecord2[i].toString());
        expect(zDAORecord[i].toString()).to.be.equal(zDAORecord3[i].toString());
      }
      expect(zDAORecord.length).to.be.equal(zDAORecord2.length);
      expect(zDAORecord.length).to.be.equal(zDAORecord3.length);
    });

    it("Should add new DAO and associate with zNA", async () => {
      await expect(zDAORegistryV2.connect(deployer).addNewDAOWithToken(ENS2, gnosisSafe2, token)).to
        .be.not.reverted;
      await expect(zDAORegistryV2.connect(zNAOwner).addZNAAssociation(2, wilder_kicks)).to.be.not
        .reverted;
      expect(await zDAORegistryV2.getzDAOIdForzNA(wilder_kicks)).to.be.equal(2);

      const zDAORecord = await zDAORegistryV2.getzDAOByzNA(wilder_kicks);
      expect(zDAORecord.id).to.be.equal(2);
      expect(zDAORecord.ensSpace).to.be.equal(ENS2);
      expect(zDAORecord.gnosisSafe).to.be.equal(gnosisSafe2);
      expect(zDAORecord.destroyed).to.be.false;
      expect(zDAORecord.token).to.be.equal(token);
    });
  });
});
