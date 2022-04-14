import {
  MockContract,
  MockContractFactory,
  smock,
} from "@defi-wonderland/smock";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import chai, { expect } from "chai";
import { ethers } from "hardhat";
import { MockToken__factory } from "../../types/factories/MockToken__factory";
import { Staking__factory } from "../../types/factories/Staking__factory";
import { MockToken } from "../../types/MockToken";
import { Staking } from "../../types/Staking";

chai.use(smock.matchers);

describe("ZDAOChef", async function () {
  let owner: SignerWithAddress,
    locker: SignerWithAddress,
    userA: SignerWithAddress,
    userB: SignerWithAddress;

  let staking: MockContract<Staking>, vToken: MockContract<MockToken>;

  beforeEach("init setup", async function () {
    [owner, locker, userA, userB] = await ethers.getSigners();

    const StakingFactory = (await smock.mock<Staking__factory>(
      "Staking"
    )) as MockContractFactory<Staking__factory>;
    staking = (await StakingFactory.deploy()) as MockContract<Staking>;
    await staking.__Staking_init();

    const MockTokenFactory = (await smock.mock<MockToken__factory>(
      "MockToken"
    )) as MockContractFactory<MockToken__factory>;
    vToken = (await MockTokenFactory.deploy()) as MockContract<MockToken>;

    await vToken.mintFor(userA.address, 10000000);
    await vToken.mintFor(userB.address, 10000000);

    await vToken
      .connect(userA)
      .approve(staking.address, ethers.constants.MaxUint256);
    await vToken
      .connect(userB)
      .approve(staking.address, ethers.constants.MaxUint256);

    // grant locker role
    await staking.grantRole(await staking.LOCKER_ROLE(), locker.address);
  });

  it("Should stake/unstake", async function () {
    // stake
    await staking.connect(userA).stake(vToken.address, 1000);
    expect(
      (await staking.userStaked(userA.address, vToken.address)).toNumber()
    ).to.be.equal(1000);
    expect((await staking.totalStaked(vToken.address)).toNumber()).to.be.equal(
      1000
    );

    // unstake
    await staking.connect(userA).unstake(vToken.address, 300);
    expect(
      (await staking.userStaked(userA.address, vToken.address)).toNumber()
    ).to.be.equal(700);
    expect((await staking.totalStaked(vToken.address)).toNumber()).to.be.equal(
      700
    );

    // stake again with another user
    await staking.connect(userB).stake(vToken.address, 2000);
    expect(
      (await staking.userStaked(userB.address, vToken.address)).toNumber()
    ).to.be.equal(2000);
    expect((await staking.totalStaked(vToken.address)).toNumber()).to.be.equal(
      2700
    );

    // check if revert to unstake more tokens
    await expect(
      staking.connect(userA).unstake(vToken.address, 1000)
    ).to.be.revertedWith("Should not exceed staked amount");
  });

  it("Should lock/unlock", async function () {
    // stake
    await staking.connect(userA).stake(vToken.address, 1000);
    await staking.connect(userB).stake(vToken.address, 2000);

    // lock
    await expect(
      staking.connect(userA).lock(vToken.address)
    ).to.be.revertedWith("Should have locker role");
    await expect(staking.connect(locker).lock(vToken.address)).to.be.not
      .reverted;
    await staking.connect(locker).lock(vToken.address); // lock twice

    const lockedRepeat = await staking.locked(vToken.address);
    expect(lockedRepeat).to.be.equal(2);

    // check if revert to unlock if already locked
    await expect(
      staking.connect(userA).unstake(vToken.address, 300)
    ).to.be.revertedWith("Should be unlocked");

    await staking.connect(locker).unlock(vToken.address);
    await staking.connect(locker).unlock(vToken.address);
    await expect(
      staking.connect(locker).unlock(vToken.address)
    ).to.be.revertedWith("Already unlocked");

    await expect(staking.connect(userA).unstake(vToken.address, 300)).to.be.not
      .reverted;
  });
});
