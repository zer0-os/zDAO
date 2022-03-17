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
      expect(await zDAOCore.zDAOs("test1DAO")).to.eql({
        metadataUri: "ipfs1",
        zNAs: [],
        admins: [user1.address],
      });
      expect(await zDAOCore.zDAOs("test2DAO")).to.eql({
        metadataUri: "ipfs2",
        zNAs: [],
        admins: [user2.address],
      });
    });
  });
});
