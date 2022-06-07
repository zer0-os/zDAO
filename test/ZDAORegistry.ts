import {
  FakeContract,
  MockContract,
  MockContractFactory,
  smock,
} from "@defi-wonderland/smock";
import chai from "chai";
import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
  IZNSHub,
  SnapshotZDAOChef,
  SnapshotZDAOChef__factory,
  ZDAORegistry,
  ZDAORegistry__factory,
} from "../types";
import { PlatformType } from "../scripts/shared/config";
import { BigNumber } from "ethers";

chai.use(smock.matchers);

interface zNAPair {
  zNA: number;
  gnosisSafe: string;
  ens: string;
}

describe("ZDAORegistry", function () {
  let deployer: SignerWithAddress,
    user1: SignerWithAddress,
    user2: SignerWithAddress,
    user3: SignerWithAddress;

  let znsHub: FakeContract<IZNSHub>,
    zDAORegistry: MockContract<ZDAORegistry>,
    snapshotZDAOChef: MockContract<SnapshotZDAOChef>;

  const zNAPairs: zNAPair[] = [];

  const validateDAOInformation = async (
    platformType: number,
    daoId: number,
    gnosisSafe: string,
    ens: string,
    zNAs: number[]
  ) => {
    const zDAO = await zDAORegistry.zDAORecords(daoId);
    expect(zDAO.platformType.toNumber()).to.be.equal(platformType);
    expect(zDAO.id.toNumber()).to.be.equal(daoId);
    expect(zDAO.gnosisSafe).to.be.equal(gnosisSafe);

    const zDAOZNAs = await zDAORegistry.getZDAOZNAs(daoId);
    const zDAOZNAsAs = zDAOZNAs.map((zNA) => zNA.toNumber());
    expect(zDAOZNAsAs).to.eql(zNAs);

    const zDAOInfo = await snapshotZDAOChef.zDAOInfos(daoId);
    expect(zDAOInfo.ensSpace).to.be.equal(ens);
  };

  beforeEach("init setup", async function () {
    [deployer, user1, user2, user3] = await ethers.getSigners();

    znsHub = (await smock.fake("IZNSHub")) as FakeContract<IZNSHub>;

    const zDAORegistryFactory = (await smock.mock<ZDAORegistry__factory>(
      "ZDAORegistry"
    )) as MockContractFactory<ZDAORegistry__factory>;
    zDAORegistry =
      (await zDAORegistryFactory.deploy()) as MockContract<ZDAORegistry>;
    await zDAORegistry.__ZDAORegistry_init(znsHub.address);

    const snapshotZDAOChefFactory =
      (await smock.mock<SnapshotZDAOChef__factory>(
        "SnapshotZDAOChef"
      )) as MockContractFactory<SnapshotZDAOChef__factory>;
    snapshotZDAOChef =
      (await snapshotZDAOChefFactory.deploy()) as MockContract<SnapshotZDAOChef>;
    await snapshotZDAOChef.__SnapshotZDAOChef_init(zDAORegistry.address);

    await zDAORegistry.addZDAOFactory(
      PlatformType.Snapshot,
      snapshotZDAOChef.address
    );

    const count = 3;
    for (let i = 0; i < count; i++) {
      zNAPairs.push({
        zNA: i + 1,
        gnosisSafe: ethers.Wallet.createRandom().address,
        ens: `ens${i + 1}`,
      });
    }
  });

  describe("#addNewDAO", () => {
    it("adds new dao record", async function () {
      znsHub.ownerOf.whenCalledWith(zNAPairs[0].zNA).returns(deployer.address);
      znsHub.ownerOf.whenCalledWith(zNAPairs[1].zNA).returns(deployer.address);

      await zDAORegistry.addNewZDAO(
        PlatformType.Snapshot, // platformType
        zNAPairs[0].zNA, // zNA
        zNAPairs[0].gnosisSafe,
        ethers.utils.solidityPack(["string"], [zNAPairs[0].ens])
      );
      await zDAORegistry.addNewZDAO(
        PlatformType.Snapshot, // platformType
        zNAPairs[1].zNA, // zNA
        zNAPairs[1].gnosisSafe,
        ethers.utils.solidityPack(["string"], [zNAPairs[1].ens])
      );

      validateDAOInformation(
        PlatformType.Snapshot,
        1,
        zNAPairs[0].gnosisSafe,
        zNAPairs[0].ens,
        [1]
      );
      validateDAOInformation(
        PlatformType.Snapshot,
        2,
        zNAPairs[1].gnosisSafe,
        zNAPairs[1].ens,
        [2]
      );
    });

    it("blocks when ens is already added", async function () {
      znsHub.ownerOf.whenCalledWith(zNAPairs[0].zNA).returns(deployer.address);

      await zDAORegistry.addNewZDAO(
        PlatformType.Snapshot, // platformType
        zNAPairs[0].zNA, // zNA
        zNAPairs[0].gnosisSafe,
        ethers.utils.solidityPack(["string"], [zNAPairs[0].ens])
      );

      await expect(
        zDAORegistry.addNewZDAO(
          PlatformType.Snapshot, // platformType
          zNAPairs[0].zNA, // zNA
          zNAPairs[0].gnosisSafe,
          ethers.utils.solidityPack(["string"], [zNAPairs[0].ens])
        )
      ).to.revertedWith("Already added DAO with same zNA");
    });
  });

  describe("#addZNAAssociation", () => {
    it("adds new zna association", async function () {
      znsHub.ownerOf.whenCalledWith(zNAPairs[0].zNA).returns(user1.address);
      znsHub.ownerOf.whenCalledWith(zNAPairs[1].zNA).returns(user2.address);
      znsHub.ownerOf.whenCalledWith(zNAPairs[2].zNA).returns(user3.address);

      await zDAORegistry.connect(user1).addNewZDAO(
        PlatformType.Snapshot, // platformType
        zNAPairs[0].zNA, // zNA
        zNAPairs[0].gnosisSafe,
        ethers.utils.solidityPack(["string"], [zNAPairs[0].ens])
      );
      await zDAORegistry.connect(user2).addNewZDAO(
        PlatformType.Snapshot, // platformType
        zNAPairs[1].zNA, // zNA
        zNAPairs[1].gnosisSafe,
        ethers.utils.solidityPack(["string"], [zNAPairs[1].ens])
      );

      await zDAORegistry.connect(user3).addZNAAssociation(1, zNAPairs[2].zNA);

      expect(await zDAORegistry.zNATozDAOId(zNAPairs[0].zNA)).to.eq(
        BigNumber.from(1)
      );
      expect(await zDAORegistry.zNATozDAOId(zNAPairs[1].zNA)).to.eq(
        BigNumber.from(2)
      );
      expect(await zDAORegistry.zNATozDAOId(zNAPairs[2].zNA)).to.eq(
        BigNumber.from(1)
      );

      validateDAOInformation(
        PlatformType.Snapshot,
        1,
        zNAPairs[0].gnosisSafe,
        zNAPairs[0].ens,
        [zNAPairs[0].zNA, zNAPairs[2].zNA]
      );
      validateDAOInformation(
        PlatformType.Snapshot,
        2,
        zNAPairs[1].gnosisSafe,
        zNAPairs[1].ens,
        [zNAPairs[1].zNA]
      );
    });

    it("renews existing association", async function () {
      znsHub.ownerOf.whenCalledWith(zNAPairs[0].zNA).returns(user1.address);
      znsHub.ownerOf.whenCalledWith(zNAPairs[1].zNA).returns(user2.address);

      await zDAORegistry.connect(user1).addNewZDAO(
        PlatformType.Snapshot, // platformType
        zNAPairs[0].zNA, // zNA
        zNAPairs[0].gnosisSafe,
        ethers.utils.solidityPack(["string"], [zNAPairs[0].ens])
      );
      await zDAORegistry.connect(user2).addNewZDAO(
        PlatformType.Snapshot, // platformType
        zNAPairs[1].zNA, // zNA
        zNAPairs[1].gnosisSafe,
        ethers.utils.solidityPack(["string"], [zNAPairs[1].ens])
      );

      await zDAORegistry.connect(user2).addZNAAssociation(1, zNAPairs[1].zNA);
      await expect(
        zDAORegistry.connect(user2).addZNAAssociation(1, zNAPairs[1].zNA)
      ).to.be.revertedWith("zNA already linked to DAO");

      expect(await zDAORegistry.zNATozDAOId(zNAPairs[1].zNA)).to.eq(
        BigNumber.from(1)
      );

      validateDAOInformation(
        PlatformType.Snapshot,
        1,
        zNAPairs[0].gnosisSafe,
        zNAPairs[0].ens,
        [zNAPairs[0].zNA, zNAPairs[1].zNA]
      );
    });
  });

  describe("#removezNAAssociation", () => {
    it("removes existing association", async function () {
      znsHub.ownerOf.whenCalledWith(zNAPairs[0].zNA).returns(user1.address);
      znsHub.ownerOf.whenCalledWith(zNAPairs[1].zNA).returns(user2.address);

      await zDAORegistry.connect(user1).addNewZDAO(
        PlatformType.Snapshot, // platformType
        zNAPairs[0].zNA, // zNA
        zNAPairs[0].gnosisSafe,
        ethers.utils.solidityPack(["string"], [zNAPairs[0].ens])
      );
      await zDAORegistry.connect(user2).addZNAAssociation(1, zNAPairs[1].zNA);
      await zDAORegistry
        .connect(user1)
        .removeZNAAssociation(1, zNAPairs[0].zNA);

      validateDAOInformation(
        PlatformType.Snapshot,
        1,
        zNAPairs[0].gnosisSafe,
        zNAPairs[0].ens,
        [zNAPairs[1].zNA]
      );
      expect(
        (await zDAORegistry.zNATozDAOId(zNAPairs[1].zNA)).toNumber()
      ).to.eq(1);
    });
    it("reverts", async function () {
      znsHub.ownerOf.whenCalledWith(zNAPairs[0].zNA).returns(user1.address);
      znsHub.ownerOf.whenCalledWith(zNAPairs[1].zNA).returns(user2.address);

      await zDAORegistry.connect(user1).addNewZDAO(
        PlatformType.Snapshot, // platformType
        zNAPairs[0].zNA, // zNA
        zNAPairs[0].gnosisSafe,
        ethers.utils.solidityPack(["string"], [zNAPairs[0].ens])
      );
      await zDAORegistry
        .connect(user1)
        .removeZNAAssociation(1, zNAPairs[0].zNA);

      await expect(
        zDAORegistry.connect(user1).removeZNAAssociation(1, zNAPairs[0].zNA)
      ).to.revertedWith("zNA not associated");
    });
  });
});
