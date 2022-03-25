import { BigNumber } from "ethers";
/* eslint-disable no-console */
/* eslint-disable @typescript-eslint/no-extra-semi */
import chai from "chai";
import { solidity } from "ethereum-waffle";
import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "hardhat-deploy-ethers/dist/src/signers";

import {
  ZNSHubTest,
  ZDAOCore,
  ZDAOCore__factory,
  ZDAOCoreProxy__factory,
  ZNSHubTest__factory,
} from "../types";

chai.use(solidity);

describe("ZDAOCore", function () {
  let deployer: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let user3: SignerWithAddress;
  let zDAOCoreProxyCast: ZDAOCore;
  let znsHub: ZNSHubTest;
  const gnosisSafe1 = "0x0000000000000000000000000000000000000001";
  const gnosisSafe2 = "0x0000000000000000000000000000000000000002";

  const validateDAOInformation = async (
    daoId: number,
    ens: number,
    gnosis: string,
    zNAs: number[]
  ) => {
    const zDAO = await zDAOCoreProxyCast.getZDAO(daoId);
    expect(zDAO[0].toNumber()).to.eq(daoId);
    expect(zDAO[1].toNumber()).to.eq(ens);
    expect(zDAO[2]).to.eq(gnosis);
    const zDAOZNAs = zDAO[3].map((big) => big.toNumber());
    expect(zDAOZNAs).to.eql(zNAs);
  };

  before(async function () {
    [deployer, user1, user2, user3] = await ethers.getSigners();
    const ZDAOCoreFactory: ZDAOCore__factory = await ethers.getContractFactory("ZDAOCore");

    const ZDAOCore = await ZDAOCoreFactory.deploy();
    await ZDAOCore.deployed();

    const ZDAOCoreProxyFactory: ZDAOCoreProxy__factory = await ethers.getContractFactory(
      "ZDAOCoreProxy"
    );

    const proxy = await ZDAOCoreProxyFactory.deploy(ZDAOCore.address, process.env.PROXY_ADMIN);
    await proxy.deployed();

    zDAOCoreProxyCast = await ethers.getContractAt("ZDAOCore", proxy.address);

    // deploy Test ZNS Hub
    const ZNSHubFactory: ZNSHubTest__factory = await ethers.getContractFactory("ZNSHubTest");
    znsHub = await ZNSHubFactory.deploy();
    await znsHub.deployed();

    // set test owners
    await Promise.all([
      znsHub.setOwnerOf(1, user1.address),
      znsHub.setOwnerOf(2, user2.address),
      znsHub.setOwnerOf(3, user3.address),
      znsHub.setOwnerOf(4, user3.address),
    ]);

    const initializeTx = await zDAOCoreProxyCast.initialize(znsHub.address);
    await initializeTx.wait();
  });

  describe("#addNewDAO", () => {
    it("adds new dao record", async function () {
      await zDAOCoreProxyCast.addNewDAO(1, gnosisSafe1);
      await zDAOCoreProxyCast.addNewDAO(2, gnosisSafe2);
      const ensHashes = await zDAOCoreProxyCast.getEnsHashes();
      expect(ensHashes.length).to.eq(2);
      expect(ensHashes[0].toNumber()).to.eq(1);
      expect(ensHashes[1].toNumber()).to.eq(2);
      expect(await zDAOCoreProxyCast.ensPresence(1)).to.eq(true);
      expect(await zDAOCoreProxyCast.ensPresence(2)).to.eq(true);

      validateDAOInformation(1, 1, gnosisSafe1, []);
      validateDAOInformation(2, 2, gnosisSafe2, []);
    });

    it("blocks when ens is already added", async function () {
      await expect(zDAOCoreProxyCast.addNewDAO(1, gnosisSafe1)).to.revertedWith("Already added");
    });
  });

  describe("#addZNAAssociation", () => {
    it("adds new zna association", async function () {
      await Promise.all([
        zDAOCoreProxyCast.connect(user1).addZNAAssociation(1, 1),
        zDAOCoreProxyCast.connect(user2).addZNAAssociation(1, 2),
        zDAOCoreProxyCast.connect(user3).addZNAAssociation(2, 3),
      ]);

      expect(await zDAOCoreProxyCast.zNATozDAO(1)).to.eq(BigNumber.from(1));
      expect(await zDAOCoreProxyCast.zNATozDAO(2)).to.eq(BigNumber.from(1));
      expect(await zDAOCoreProxyCast.zNATozDAO(3)).to.eq(BigNumber.from(2));

      validateDAOInformation(1, 1, gnosisSafe1, [1, 2]);
      validateDAOInformation(2, 2, gnosisSafe2, [3]);
    });

    it("renews existing association", async function () {
      await zDAOCoreProxyCast.connect(user2).addZNAAssociation(2, 2);
      validateDAOInformation(1, 1, gnosisSafe1, [1]);
      validateDAOInformation(2, 2, gnosisSafe2, [3, 2]);
      expect(await zDAOCoreProxyCast.zNATozDAO(1)).to.eq(BigNumber.from(1));
      expect(await zDAOCoreProxyCast.zNATozDAO(2)).to.eq(BigNumber.from(2));
      expect(await zDAOCoreProxyCast.zNATozDAO(3)).to.eq(BigNumber.from(2));
    });
    it("reverts", async function () {
      await expect(zDAOCoreProxyCast.connect(user1).addZNAAssociation(5, 2)).to.revertedWith(
        "Invalid daoId"
      );
      await expect(zDAOCoreProxyCast.connect(user1).addZNAAssociation(2, 2)).to.revertedWith(
        "Not zNA owner"
      );

      await expect(zDAOCoreProxyCast.connect(user2).addZNAAssociation(2, 2)).to.revertedWith(
        "Already added"
      );
    });
  });

  describe("#removezNAAssociation", () => {
    it("removes existing association", async function () {
      await zDAOCoreProxyCast.connect(user2).removeZNAAssociation(2, 2);
      validateDAOInformation(2, 2, gnosisSafe2, [3]);
      expect((await zDAOCoreProxyCast.zNATozDAO(2)).toNumber()).to.eq(0);
    });
    it("reverts", async function () {
      await expect(zDAOCoreProxyCast.connect(user1).removeZNAAssociation(5, 2)).to.revertedWith(
        "Invalid daoId"
      );
      await expect(zDAOCoreProxyCast.connect(user1).removeZNAAssociation(2, 2)).to.revertedWith(
        "Not zNA owner"
      );

      await expect(zDAOCoreProxyCast.connect(user2).removeZNAAssociation(2, 2)).to.revertedWith(
        "Not associated yet"
      );
    });
  });
});
