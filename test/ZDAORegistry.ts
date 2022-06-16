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
  IERC20Upgradeable,
  IRootStateSender,
  IZNSHub,
  RootZDAOChef,
  RootZDAOChef__factory,
  SnapshotZDAOChef,
  SnapshotZDAOChef__factory,
  ZDAORegistry,
  ZDAORegistry__factory,
} from "../types";
import { PlatformType } from "../scripts/shared/config";
import { BigNumber } from "ethers";
import { ZDAOConfig } from "./shared/types";

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

  const validateSnapshotDAOInformation = async (
    platformType: number,
    daoId: number,
    gnosisSafe: string,
    ens: string,
    zNAs: number[]
  ) => {
    const zDAORecord = await zDAORegistry.zDAORecords(daoId);
    expect(zDAORecord.platformType.toNumber()).to.be.equal(platformType);
    expect(zDAORecord.id.toNumber()).to.be.equal(daoId);
    expect(zDAORecord.zDAO).to.be.equal(ethers.constants.AddressZero);
    expect(zDAORecord.gnosisSafe).to.be.equal(gnosisSafe);

    const zDAORecord2 = await zDAORegistry.getZDAOById(daoId);
    expect(zDAORecord2.platformType.toNumber()).to.be.equal(platformType);
    expect(zDAORecord2.id.toNumber()).to.be.equal(daoId);
    expect(zDAORecord2.zDAO).to.be.equal(ethers.constants.AddressZero);
    const zDAOZNAsAs = zDAORecord2.associatedzNAs.map((zNA) => zNA.toNumber());
    zDAOZNAsAs.forEach((zNA, index) => expect(zNA).to.be.equal(zNAs[index]));

    const zDAOInfo = await snapshotZDAOChef.zDAOInfos(daoId);
    expect(zDAOInfo.id.toNumber()).to.be.equal(daoId);
    expect(zDAOInfo.ensSpace).to.be.equal(ens);
    expect(zDAOInfo.gnosisSafe).to.be.equal(gnosisSafe);
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
    await snapshotZDAOChef.__ZDAOChef_init(zDAORegistry.address);

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

  describe("#addNewDAO for snapshot", () => {
    it("adds new dao record", async function () {
      znsHub.ownerOf.whenCalledWith(zNAPairs[0].zNA).returns(deployer.address);
      znsHub.ownerOf.whenCalledWith(zNAPairs[1].zNA).returns(deployer.address);

      await zDAORegistry.addNewZDAO(
        PlatformType.Snapshot, // platformType
        zNAPairs[0].zNA, // zNA
        zNAPairs[0].gnosisSafe,
        ethers.utils.defaultAbiCoder.encode(["string"], [zNAPairs[0].ens])
      );
      await zDAORegistry.addNewZDAO(
        PlatformType.Snapshot, // platformType
        zNAPairs[1].zNA, // zNA
        zNAPairs[1].gnosisSafe,
        ethers.utils.defaultAbiCoder.encode(["string"], [zNAPairs[1].ens])
      );

      validateSnapshotDAOInformation(
        PlatformType.Snapshot,
        1,
        zNAPairs[0].gnosisSafe,
        zNAPairs[0].ens,
        [1]
      );
      validateSnapshotDAOInformation(
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

  describe("#addNewDAO for polygon", () => {
    let rootStateSender: FakeContract<IRootStateSender>,
      rootZDAOChef: MockContract<RootZDAOChef>,
      vToken: FakeContract<IERC20Upgradeable>;

    let title: string, zDAOConfig: ZDAOConfig;

    const validatePolygonDAOInformation = async (
      platformType: number,
      daoId: number,
      gnosisSafe: string,
      zNAs: number[],
      title: string,
      zDAOConfig: ZDAOConfig
    ) => {
      const zDAORecord = await zDAORegistry.zDAORecords(daoId);
      expect(zDAORecord.platformType.toNumber()).to.be.equal(platformType);
      expect(zDAORecord.id.toNumber()).to.be.equal(daoId);
      expect(zDAORecord.gnosisSafe).to.be.equal(gnosisSafe);

      const zDAORecord2 = await zDAORegistry.getZDAOById(daoId);
      expect(zDAORecord2.platformType.toNumber()).to.be.equal(platformType);
      expect(zDAORecord2.id.toNumber()).to.be.equal(daoId);
      const zDAOZNAsAs = zDAORecord2.associatedzNAs.map((zNA) =>
        zNA.toNumber()
      );
      expect(zDAORecord.zDAO).to.be.equal(zDAORecord2.zDAO);
      zDAOZNAsAs.forEach((zNA, index) => expect(zNA).to.be.equal(zNAs[index]));

      const zDAOAddr = await rootZDAOChef.zDAOs(daoId);
      expect(zDAORecord.zDAO).to.be.equal(zDAOAddr);
      const zDAO = await ethers.getContractAt("RootZDAO", zDAOAddr, deployer);

      const zDAOInfo = await zDAO.zDAOInfo();
      expect(zDAOInfo.zDAOId.toNumber()).to.be.equal(daoId);
      expect(zDAOInfo.title).to.be.equal(title);
      expect(zDAOInfo.createdBy).to.be.equal(deployer.address);
      expect(zDAOInfo.gnosisSafe).to.be.equal(gnosisSafe);
      expect(zDAOInfo.token).to.be.equal(zDAOConfig.token);
      expect(zDAOInfo.amount).to.be.equal(BigNumber.from(zDAOConfig.amount));
      expect(zDAOInfo.duration.toNumber()).to.be.equal(zDAOConfig.duration);
      expect(zDAOInfo.votingThreshold.toNumber()).to.be.equal(
        zDAOConfig.votingThreshold
      );
      expect(zDAOInfo.minimumVotingParticipants.toNumber()).to.be.equal(
        zDAOConfig.minimumVotingParticipants
      );
      expect(zDAOInfo.minimumTotalVotingTokens.toNumber()).to.be.equal(
        zDAOConfig.minimumTotalVotingTokens
      );
      expect(zDAOInfo.isRelativeMajority).to.be.equal(
        zDAOConfig.isRelativeMajority
      );
      expect(zDAOInfo.destroyed).to.be.equal(false);
    };

    beforeEach("init setup for polygon", async function () {
      vToken = (await smock.fake(
        "IERC20Upgradeable"
      )) as FakeContract<IERC20Upgradeable>;

      const ZDAOChefFactory = (await smock.mock<RootZDAOChef__factory>(
        "RootZDAOChef"
      )) as MockContractFactory<RootZDAOChef__factory>;
      const ZDAOFactory = await ethers.getContractFactory("RootZDAO");
      const zDAOBase = await ZDAOFactory.deploy();

      rootStateSender = (await smock.fake(
        "IRootStateSender"
      )) as FakeContract<IRootStateSender>;

      rootZDAOChef =
        (await ZDAOChefFactory.deploy()) as MockContract<RootZDAOChef>;
      await rootZDAOChef.__ZDAOChef_init(
        zDAORegistry.address,
        rootStateSender.address,
        zDAOBase.address
      );

      await zDAORegistry.addZDAOFactory(
        PlatformType.Polygon,
        rootZDAOChef.address
      );

      title = `${zNAPairs[0].zNA}.dao`;
      zDAOConfig = {
        token: vToken.address,
        amount: BigNumber.from("10000").toNumber(),
        duration: 150, // 5 min
        votingThreshold: 5001, // 50.01%
        minimumVotingParticipants: 1,
        minimumTotalVotingTokens: 5000,
        isRelativeMajority: true,
      };
    });

    it("adds new dao record", async function () {
      znsHub.ownerOf.whenCalledWith(zNAPairs[0].zNA).returns(deployer.address);
      znsHub.ownerOf.whenCalledWith(zNAPairs[1].zNA).returns(deployer.address);

      const options = ethers.utils.defaultAbiCoder.encode(
        [
          "string",
          "address",
          "uint256",
          "uint256",
          "uint256",
          "uint256",
          "uint256",
          "bool",
        ],
        [
          title,
          zDAOConfig.token,
          zDAOConfig.amount,
          zDAOConfig.duration,
          zDAOConfig.votingThreshold,
          zDAOConfig.minimumVotingParticipants,
          zDAOConfig.minimumTotalVotingTokens,
          zDAOConfig.isRelativeMajority,
        ]
      );
      await zDAORegistry.addNewZDAO(
        PlatformType.Polygon, // platformType
        zNAPairs[0].zNA, // zNA
        zNAPairs[0].gnosisSafe,
        options
      );
      await zDAORegistry.addNewZDAO(
        PlatformType.Polygon, // platformType
        zNAPairs[1].zNA, // zNA
        zNAPairs[1].gnosisSafe,
        options
      );

      validatePolygonDAOInformation(
        PlatformType.Polygon,
        1,
        zNAPairs[0].gnosisSafe,
        [1],
        title,
        zDAOConfig
      );
      validatePolygonDAOInformation(
        PlatformType.Polygon,
        2,
        zNAPairs[1].gnosisSafe,
        [2],
        title,
        zDAOConfig
      );
    });

    it("blocks when same zNA was already added", async function () {
      znsHub.ownerOf.whenCalledWith(zNAPairs[0].zNA).returns(deployer.address);
      znsHub.ownerOf.whenCalledWith(zNAPairs[1].zNA).returns(deployer.address);

      const options = ethers.utils.defaultAbiCoder.encode(
        [
          "string",
          "address",
          "uint256",
          "uint256",
          "uint256",
          "uint256",
          "uint256",
          "bool",
        ],
        [
          title,
          zDAOConfig.token,
          zDAOConfig.amount,
          zDAOConfig.duration,
          zDAOConfig.votingThreshold,
          zDAOConfig.minimumVotingParticipants,
          zDAOConfig.minimumTotalVotingTokens,
          zDAOConfig.isRelativeMajority,
        ]
      );
      await zDAORegistry.addNewZDAO(
        PlatformType.Polygon, // platformType
        zNAPairs[0].zNA, // zNA
        zNAPairs[0].gnosisSafe,
        options
      );
      await expect(
        zDAORegistry.addNewZDAO(
          PlatformType.Polygon, // platformType
          zNAPairs[0].zNA, // zNA
          zNAPairs[0].gnosisSafe,
          options
        )
      ).to.be.revertedWith("Already added DAO with same zNA");
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

      validateSnapshotDAOInformation(
        PlatformType.Snapshot,
        1,
        zNAPairs[0].gnosisSafe,
        zNAPairs[0].ens,
        [zNAPairs[0].zNA, zNAPairs[2].zNA]
      );
      validateSnapshotDAOInformation(
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

      validateSnapshotDAOInformation(
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

      validateSnapshotDAOInformation(
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
