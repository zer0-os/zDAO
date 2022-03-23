/* eslint-disable no-console */
/* eslint-disable @typescript-eslint/no-extra-semi */
import chai from "chai";
import { solidity } from "ethereum-waffle";
import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "hardhat-deploy-ethers/dist/src/signers";

import { ZDAOCore, ZDAOCore__factory, ZDAOCoreProxy__factory } from "../types";

chai.use(solidity);

describe("zDAOCore", function () {
  let deployer: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let user3: SignerWithAddress;
  let zDAOCoreProxyCast: ZDAOCore;

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
    const initializeTx = await zDAOCoreProxyCast.initialize(process.env.ZNS_HUB);
    await initializeTx.wait();
  });

  describe("#addNewDAO", () => {
    it("adds new dao record", async function () {
      await zDAOCoreProxyCast.addNewDAO("test1DAO", "ipfs1", [user1.address]);
      await zDAOCoreProxyCast.addNewDAO("test2DAO", "ipfs2", [user2.address]);
      expect(await zDAOCoreProxyCast.getDAOIds()).to.eql(["test1DAO", "test2DAO"]);
      expect(await zDAOCoreProxyCast.zDAOIDPresence("test1DAO")).to.eq(true);
      expect(await zDAOCoreProxyCast.zDAOIDPresence("test2DAO")).to.eq(true);
      expect(await zDAOCoreProxyCast.getDAOMetadataUri("test1DAO")).to.eql("ipfs1");
      expect(await zDAOCoreProxyCast.getDAOZNAs("test1DAO")).to.eql([]);
    });

    it("blocks when called from non-managers", async function () {
      await expect(
        zDAOCoreProxyCast.connect(user1).addNewDAO("test3DAO", "ipfs3", [user2.address])
      ).to.revertedWith("Not allowed");
    });
  });

  describe("#addZNAAssociation", () => {
    it("adds new zna association", async function () {
      await zDAOCoreProxyCast.connect(user1).addZNAAssociation("test1DAO", "zNA1");
      expect(await zDAOCoreProxyCast.getDAOZNAs("test1DAO")).to.eql(["zNA1"]);
      await zDAOCoreProxyCast.connect(user2).addZNAAssociation("test2DAO", "zNA2");
      expect(await zDAOCoreProxyCast.getDAOZNAs("test2DAO")).to.eql(["zNA2"]);
      await zDAOCoreProxyCast.connect(user2).addZNAAssociation("test2DAO", "zNA3");
      expect(await zDAOCoreProxyCast.getDAOZNAs("test2DAO")).to.eql(["zNA2", "zNA3"]);

      expect(await zDAOCoreProxyCast.zNATozDAO("zNA1")).to.eq("test1DAO");
      expect(await zDAOCoreProxyCast.zNATozDAO("zNA2")).to.eq("test2DAO");
      expect(await zDAOCoreProxyCast.zNATozDAO("zNA3")).to.eq("test2DAO");
    });
    it("renews existing association", async function () {
      await zDAOCoreProxyCast.connect(user1).addZNAAssociation("test1DAO", "zNA3");
      expect(await zDAOCoreProxyCast.getDAOZNAs("test1DAO")).to.eql(["zNA1", "zNA3"]);
      expect(await zDAOCoreProxyCast.getDAOZNAs("test2DAO")).to.eql(["zNA2"]);
      expect(await zDAOCoreProxyCast.zNATozDAO("zNA1")).to.eq("test1DAO");
      expect(await zDAOCoreProxyCast.zNATozDAO("zNA2")).to.eq("test2DAO");
      expect(await zDAOCoreProxyCast.zNATozDAO("zNA3")).to.eq("test1DAO");
    });
    it("reverts", async function () {
      await expect(
        zDAOCoreProxyCast.connect(user2).addZNAAssociation("test1DAO", "zNA3")
      ).to.revertedWith("Only DAO admins can update association");
      await expect(
        zDAOCoreProxyCast.connect(user1).addZNAAssociation("testxDAO", "zNA4")
      ).to.revertedWith("DAO ID invalid");

      await expect(
        zDAOCoreProxyCast.connect(user1).addZNAAssociation("test1DAO", "zNA1")
      ).to.revertedWith("Already added");
    });
  });

  describe("#removezNAAssociation", () => {
    it("removes existing association", async function () {
      await zDAOCoreProxyCast.connect(user1).removeZNAAssociation("test1DAO", "zNA3");
      expect(await zDAOCoreProxyCast.getDAOZNAs("test1DAO")).to.eql(["zNA1"]);
      expect(await zDAOCoreProxyCast.zNATozDAO("zNA3")).to.eq("");
    });
    it("reverts", async function () {
      await expect(
        zDAOCoreProxyCast.connect(user2).removeZNAAssociation("test1DAO", "zNA4")
      ).to.revertedWith("Only DAO admins can update association");
      await expect(
        zDAOCoreProxyCast.connect(user1).removeZNAAssociation("testxDAO", "zNA4")
      ).to.revertedWith("DAO ID invalid");
    });
  });

  describe("#setDAOAdmin", () => {
    it("set dao admin and update association", async function () {
      await zDAOCoreProxyCast.connect(user1).setDAOAdmin("test1DAO", user3.address, true);
      await zDAOCoreProxyCast.connect(user3).addZNAAssociation("test1DAO", "zNA5");
      expect(await zDAOCoreProxyCast.getDAOZNAs("test1DAO")).to.eql(["zNA1", "zNA5"]);

      await zDAOCoreProxyCast.connect(user1).setDAOAdmin("test1DAO", user3.address, false);
      await expect(
        zDAOCoreProxyCast.connect(user3).removeZNAAssociation("test1DAO", "zNA4")
      ).to.revertedWith("Only DAO admins can update association");
    });
  });

  describe("#setDAOMetadataUri", () => {
    it("updates dao metadatauri", async function () {
      await zDAOCoreProxyCast.connect(user1).setDAOMetadataUri("test1DAO", "updated");
      expect(await zDAOCoreProxyCast.getDAOMetadataUri("test1DAO")).to.eq("updated");
    });
  });
});
