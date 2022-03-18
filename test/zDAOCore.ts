/* eslint-disable no-console */
/* eslint-disable @typescript-eslint/no-extra-semi */
import chai from "chai";
import { solidity } from "ethereum-waffle";
import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "hardhat-deploy-ethers/dist/src/signers";

import { ZDAOCore, ZDAOCore__factory } from "../types";

chai.use(solidity);

describe("zDAOCore", function () {
  let deployer: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let user3: SignerWithAddress;
  let zDAOCore: ZDAOCore;

  before(async function () {
    [deployer, user1, user2, user3] = await ethers.getSigners();
    const zDAOCoreFactory: ZDAOCore__factory = await ethers.getContractFactory("zDAOCore");
    zDAOCore = await zDAOCoreFactory.connect(deployer).deploy();
    await zDAOCore.deployed();
  });

  describe("#addNewDAO", () => {
    it("adds new dao record", async function () {
      await zDAOCore.addNewDAO("test1DAO", "ipfs1", [user1.address]);
      await zDAOCore.addNewDAO("test2DAO", "ipfs2", [user2.address]);
      expect(await zDAOCore.getDAOIds()).to.eql(["test1DAO", "test2DAO"]);
      expect(await zDAOCore.zDAOIDPresence("test1DAO")).to.eq(true);
      expect(await zDAOCore.zDAOIDPresence("test2DAO")).to.eq(true);
      expect(await zDAOCore.getDAOMetadataUri("test1DAO")).to.eql("ipfs1");
      expect(await zDAOCore.getDAOZNAs("test1DAO")).to.eql([]);
    });

    it("blocks when called from non-managers", async function () {
      await expect(
        zDAOCore.connect(user1).addNewDAO("test3DAO", "ipfs3", [user2.address])
      ).to.revertedWith("Not allowed");
    });
  });

  describe("#addZNAAssociation", () => {
    it("adds new zna association", async function () {
      await zDAOCore.connect(user1).addZNAAssociation("test1DAO", "zNA1");
      expect(await zDAOCore.getDAOZNAs("test1DAO")).to.eql(["zNA1"]);
      await zDAOCore.connect(user2).addZNAAssociation("test2DAO", "zNA2");
      expect(await zDAOCore.getDAOZNAs("test2DAO")).to.eql(["zNA2"]);
      await zDAOCore.connect(user2).addZNAAssociation("test2DAO", "zNA3");
      expect(await zDAOCore.getDAOZNAs("test2DAO")).to.eql(["zNA2", "zNA3"]);

      expect(await zDAOCore.zNATozDAO("zNA1")).to.eq("test1DAO");
      expect(await zDAOCore.zNATozDAO("zNA2")).to.eq("test2DAO");
      expect(await zDAOCore.zNATozDAO("zNA3")).to.eq("test2DAO");
    });
    it("renews existing association", async function () {
      await zDAOCore.connect(user1).addZNAAssociation("test1DAO", "zNA3");
      expect(await zDAOCore.getDAOZNAs("test1DAO")).to.eql(["zNA1", "zNA3"]);
      expect(await zDAOCore.getDAOZNAs("test2DAO")).to.eql(["zNA2"]);
      expect(await zDAOCore.zNATozDAO("zNA1")).to.eq("test1DAO");
      expect(await zDAOCore.zNATozDAO("zNA2")).to.eq("test2DAO");
      expect(await zDAOCore.zNATozDAO("zNA3")).to.eq("test1DAO");
    });
    it("reverts", async function () {
      await expect(zDAOCore.connect(user2).addZNAAssociation("test1DAO", "zNA3")).to.revertedWith(
        "Only DAO admins can update association"
      );
      await expect(zDAOCore.connect(user1).addZNAAssociation("testxDAO", "zNA4")).to.revertedWith(
        "DAO ID invalid"
      );

      await expect(zDAOCore.connect(user1).addZNAAssociation("test1DAO", "zNA1")).to.revertedWith(
        "Already added"
      );
    });
  });

  describe("#removezNAAssociation", () => {
    it("removes existing association", async function () {
      await zDAOCore.connect(user1).removeZNAAssociation("test1DAO", "zNA3");
      expect(await zDAOCore.getDAOZNAs("test1DAO")).to.eql(["zNA1"]);
      expect(await zDAOCore.zNATozDAO("zNA3")).to.eq("");
    });
    it("reverts", async function () {
      await expect(
        zDAOCore.connect(user2).removeZNAAssociation("test1DAO", "zNA4")
      ).to.revertedWith("Only DAO admins can update association");
      await expect(
        zDAOCore.connect(user1).removeZNAAssociation("testxDAO", "zNA4")
      ).to.revertedWith("DAO ID invalid");
    });
  });

  describe("#setDAOAdmin", () => {
    it("set dao admin and update association", async function () {
      await zDAOCore.connect(user1).setDAOAdmin("test1DAO", user3.address, true);
      await zDAOCore.connect(user3).addZNAAssociation("test1DAO", "zNA5");
      expect(await zDAOCore.getDAOZNAs("test1DAO")).to.eql(["zNA1", "zNA5"]);

      await zDAOCore.connect(user1).setDAOAdmin("test1DAO", user3.address, false);
      await expect(
        zDAOCore.connect(user3).removeZNAAssociation("test1DAO", "zNA4")
      ).to.revertedWith("Only DAO admins can update association");
    });
  });

  describe("#setDAOMetadataUri", () => {
    it("updates dao metadatauri", async function () {
      await zDAOCore.connect(user1).setDAOMetadataUri("test1DAO", "updated");
      expect(await zDAOCore.getDAOMetadataUri("test1DAO")).to.eq("updated");
    });
  });
});
