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
  IEthereumStateSender,
  EthereumZDAOChef,
  EthereumZDAOChef__factory,
  SnapshotZDAOChef,
  SnapshotZDAOChef__factory,
  ZDAORegistry,
  ZDAORegistry__factory,
} from "../types";
import { PlatformType } from "../scripts/shared/config";
import { BigNumber } from "ethers";
import { ZDAOConfig } from "./shared/types";

chai.use(smock.matchers);

interface zDAOPair {
  gnosisSafe: string;
  name: string;
  ens: string;
}

describe("ZDAORegistry", function () {
  let deployer: SignerWithAddress,
    user1: SignerWithAddress,
    user2: SignerWithAddress,
    user3: SignerWithAddress;

  let zDAORegistry: MockContract<ZDAORegistry>,
    snapshotZDAOChef: MockContract<SnapshotZDAOChef>;

  const zDAOPairs: zDAOPair[] = [];

  const validateSnapshotDAOInformation = async (
    platformType: number,
    daoId: number,
    gnosisSafe: string,
    name: string,
    ens: string
  ) => {
    const zDAORecord = await zDAORegistry.zDAORecords(daoId);
    expect(zDAORecord.platformType.toNumber()).to.be.equal(platformType);
    expect(zDAORecord.id.toNumber()).to.be.equal(daoId);
    expect(zDAORecord.gnosisSafe).to.be.equal(gnosisSafe);
    expect(zDAORecord.name).to.be.equal(name);

    const zDAORecord2 = await zDAORegistry.getZDAOById(daoId);
    expect(zDAORecord2.platformType.toNumber()).to.be.equal(platformType);
    expect(zDAORecord2.id.toNumber()).to.be.equal(daoId);

    const zDAOInfo = await snapshotZDAOChef.zDAOInfos(daoId);
    expect(zDAOInfo.id.toNumber()).to.be.equal(daoId);
    expect(zDAOInfo.ensSpace).to.be.equal(ens);
    expect(zDAOInfo.gnosisSafe).to.be.equal(gnosisSafe);
  };

  beforeEach("init setup", async function () {
    [deployer, user1, user2, user3] = await ethers.getSigners();

    const zDAORegistryFactory = (await smock.mock<ZDAORegistry__factory>(
      "ZDAORegistry"
    )) as MockContractFactory<ZDAORegistry__factory>;
    zDAORegistry =
      (await zDAORegistryFactory.deploy()) as MockContract<ZDAORegistry>;
    await zDAORegistry.__ZDAORegistry_init();

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
      zDAOPairs.push({
        gnosisSafe: ethers.Wallet.createRandom().address,
        name: `ens${i + 1}-name`,
        ens: `ens${i + 1}`,
      });
    }
  });

  describe("Check addNewDAO for snapshot", () => {
    it("adds new dao record", async function () {
      await zDAORegistry.addNewZDAO(
        PlatformType.Snapshot, // platformType
        zDAOPairs[0].gnosisSafe,
        zDAOPairs[0].name,
        ethers.utils.defaultAbiCoder.encode(["string"], [zDAOPairs[0].ens])
      );
      await zDAORegistry.addNewZDAO(
        PlatformType.Snapshot, // platformType
        zDAOPairs[1].gnosisSafe,
        zDAOPairs[1].name,
        ethers.utils.defaultAbiCoder.encode(["string"], [zDAOPairs[1].ens])
      );

      validateSnapshotDAOInformation(
        PlatformType.Snapshot,
        1,
        zDAOPairs[0].gnosisSafe,
        zDAOPairs[0].name,
        zDAOPairs[0].ens
      );
      validateSnapshotDAOInformation(
        PlatformType.Snapshot,
        2,
        zDAOPairs[1].gnosisSafe,
        zDAOPairs[1].name,
        zDAOPairs[1].ens
      );
    });

    it("blocks when ens is already added", async function () {
      await zDAORegistry.addNewZDAO(
        PlatformType.Snapshot, // platformType
        zDAOPairs[0].gnosisSafe,
        zDAOPairs[0].name,
        ethers.utils.defaultAbiCoder.encode(["string"], [zDAOPairs[0].ens])
      );

      await expect(
        zDAORegistry.addNewZDAO(
          PlatformType.Snapshot, // platformType
          zDAOPairs[0].gnosisSafe,
          zDAOPairs[0].name,
          ethers.utils.defaultAbiCoder.encode(["string"], [zDAOPairs[0].ens])
        )
      ).to.revertedWith("Already added zDAO with same name");
    });
  });

  describe("Check addNewDAO for polygon", () => {
    let ethereumStateSender: FakeContract<IEthereumStateSender>,
      rootZDAOChef: MockContract<EthereumZDAOChef>,
      vToken: FakeContract<IERC20Upgradeable>;

    let name: string, zDAOConfig: ZDAOConfig;

    const validatePolygonDAOInformation = async (
      platformType: number,
      daoId: number,
      gnosisSafe: string,
      name: string,
      zDAOConfig: ZDAOConfig
    ) => {
      const zDAORecord = await zDAORegistry.zDAORecords(daoId);
      expect(zDAORecord.platformType.toNumber()).to.be.equal(platformType);
      expect(zDAORecord.id.toNumber()).to.be.equal(daoId);
      expect(zDAORecord.gnosisSafe).to.be.equal(gnosisSafe);
      expect(zDAORecord.name).to.be.equal(name);

      const zDAORecord2 = await zDAORegistry.getZDAOById(daoId);
      expect(zDAORecord2.platformType.toNumber()).to.be.equal(platformType);
      expect(zDAORecord2.id.toNumber()).to.be.equal(daoId);
      expect(zDAORecord2.name).to.be.equal(zDAORecord.name);

      const zDAOAddr = await rootZDAOChef.zDAOs(daoId);
      const zDAO = await ethers.getContractAt(
        "EthereumZDAO",
        zDAOAddr,
        deployer
      );

      const zDAOInfo = await zDAO.zDAOInfo();
      expect(zDAOInfo.zDAOId.toNumber()).to.be.equal(daoId);
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

      const ZDAOChefFactory = (await smock.mock<EthereumZDAOChef__factory>(
        "EthereumZDAOChef"
      )) as MockContractFactory<EthereumZDAOChef__factory>;
      const ZDAOFactory = await ethers.getContractFactory("EthereumZDAO");
      const zDAOBase = await ZDAOFactory.deploy();

      ethereumStateSender = (await smock.fake(
        "IEthereumStateSender"
      )) as FakeContract<IEthereumStateSender>;

      rootZDAOChef =
        (await ZDAOChefFactory.deploy()) as MockContract<EthereumZDAOChef>;
      await rootZDAOChef.__ZDAOChef_init(
        zDAORegistry.address,
        ethereumStateSender.address,
        zDAOBase.address
      );

      await zDAORegistry.addZDAOFactory(
        PlatformType.Polygon,
        rootZDAOChef.address
      );

      name = `${zDAOPairs[0].ens}.dao`;
      zDAOConfig = {
        token: vToken.address,
        amount: BigNumber.from("10000").toNumber(),
        duration: 150, // 5 min
        votingDelay: 0,
        votingThreshold: 5001, // 50.01%
        minimumVotingParticipants: 1,
        minimumTotalVotingTokens: 5000,
        isRelativeMajority: true,
      };
    });

    it("adds new dao record", async function () {
      const options = ethers.utils.defaultAbiCoder.encode(
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
      );
      await zDAORegistry.addNewZDAO(
        PlatformType.Polygon, // platformType
        zDAOPairs[0].gnosisSafe,
        zDAOPairs[0].name,
        options
      );
      await zDAORegistry.addNewZDAO(
        PlatformType.Polygon, // platformType
        zDAOPairs[1].gnosisSafe,
        zDAOPairs[1].name,
        options
      );

      validatePolygonDAOInformation(
        PlatformType.Polygon,
        1,
        zDAOPairs[0].gnosisSafe,
        zDAOPairs[0].name,
        zDAOConfig
      );
      validatePolygonDAOInformation(
        PlatformType.Polygon,
        2,
        zDAOPairs[1].gnosisSafe,
        zDAOPairs[1].name,
        zDAOConfig
      );
    });
  });

  describe("Check ResourceRegistry", () => {
    it("resource should exist", async function () {
      // Add new DAO
      await zDAORegistry.connect(user1).addNewZDAO(
        PlatformType.Snapshot, // platformType
        zDAOPairs[0].gnosisSafe,
        zDAOPairs[0].name,
        ethers.utils.defaultAbiCoder.encode(["string"], [zDAOPairs[0].ens])
      );

      const zDAOId = 1,
        emptyZDAOID = 0;
      const exists = await zDAORegistry.resourceExists(zDAOId);
      expect(exists).to.be.equal(true);

      const notExists = await zDAORegistry.resourceExists(emptyZDAOID);
      expect(notExists).to.be.equal(false);
    });

    it("destroyed resource should not exist", async function () {
      // Add new DAO
      await zDAORegistry.connect(user1).addNewZDAO(
        PlatformType.Snapshot, // platformType
        zDAOPairs[0].gnosisSafe,
        zDAOPairs[0].name,
        ethers.utils.defaultAbiCoder.encode(["string"], [zDAOPairs[0].ens])
      );

      // Destroy it
      const zDAOId = 1;
      await zDAORegistry.connect(deployer).removeZDAO(zDAOId);

      const notExists = await zDAORegistry.resourceExists(zDAOId);
      expect(notExists).to.be.equal(false);
    });
  });
});
