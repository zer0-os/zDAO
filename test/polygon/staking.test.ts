import {
  MockContract,
  MockContractFactory,
  smock,
} from "@defi-wonderland/smock";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import chai, { expect } from "chai";
import { ethers } from "hardhat";
import { MockCollectibleUpgradeable__factory } from "../../types/factories/MockCollectibleUpgradeable__factory";
import { MockTokenUpgradeable__factory } from "../../types/factories/MockTokenUpgradeable__factory";
import { Staking__factory } from "../../types/factories/Staking__factory";
import { MockCollectibleUpgradeable } from "../../types/MockCollectibleUpgradeable";
import { MockTokenUpgradeable } from "../../types/MockTokenUpgradeable";
import { Staking } from "../../types/Staking";

chai.use(smock.matchers);

describe("Staking", async function () {
  let owner: SignerWithAddress,
    locker: SignerWithAddress,
    userA: SignerWithAddress,
    userB: SignerWithAddress;

  let staking: MockContract<Staking>,
    vToken: MockContract<MockTokenUpgradeable>,
    vCollectible: MockContract<MockCollectibleUpgradeable>;

  beforeEach("init setup", async function () {
    [owner, locker, userA, userB] = await ethers.getSigners();

    const StakingFactory = (await smock.mock<Staking__factory>(
      "Staking"
    )) as MockContractFactory<Staking__factory>;
    staking = (await StakingFactory.deploy()) as MockContract<Staking>;
    await staking.__Staking_init();

    const MockTokenUpgradeableFactory =
      (await smock.mock<MockTokenUpgradeable__factory>(
        "MockTokenUpgradeable"
      )) as MockContractFactory<MockTokenUpgradeable__factory>;
    vToken =
      (await MockTokenUpgradeableFactory.deploy()) as MockContract<MockTokenUpgradeable>;
    await vToken.__MockTokenUpgradeable_init("vToken", "VT");

    const MockCollectibleUpgradeableFactory =
      (await smock.mock<MockCollectibleUpgradeable__factory>(
        "MockCollectibleUpgradeable"
      )) as MockContractFactory<MockCollectibleUpgradeable__factory>;
    vCollectible =
      (await MockCollectibleUpgradeableFactory.deploy()) as MockContract<MockCollectibleUpgradeable>;
    await vCollectible.__MockCollectibleUpgradeable_init("vCollectible", "VC");

    await vToken.mintFor(userA.address, 10000000);
    await vToken.mintFor(userB.address, 10000000);

    // grant locker role
    await staking.grantRole(await staking.LOCKER_ROLE(), locker.address);
  });

  it("Should stake/unstake ERC20", async function () {
    // approve
    await vToken
      .connect(userA)
      .approve(staking.address, ethers.constants.MaxUint256);
    await vToken
      .connect(userB)
      .approve(staking.address, ethers.constants.MaxUint256);

    // stake
    await staking.connect(userA).stakeERC20(vToken.address, 1000);
    expect(
      (await staking.userStaked(userA.address, vToken.address)).toNumber()
    ).to.be.equal(1000);
    expect((await staking.totalStaked(vToken.address)).toNumber()).to.be.equal(
      1000
    );

    // unstake
    await staking.connect(userA).unstakeERC20(vToken.address, 300);
    expect(
      (await staking.userStaked(userA.address, vToken.address)).toNumber()
    ).to.be.equal(700);
    expect((await staking.totalStaked(vToken.address)).toNumber()).to.be.equal(
      700
    );

    // stake again with another user
    await staking.connect(userB).stakeERC20(vToken.address, 2000);
    expect(
      (await staking.userStaked(userB.address, vToken.address)).toNumber()
    ).to.be.equal(2000);
    expect((await staking.totalStaked(vToken.address)).toNumber()).to.be.equal(
      2700
    );

    // check if revert to unstake more tokens
    await expect(
      staking.connect(userA).unstakeERC20(vToken.address, 1000)
    ).to.be.revertedWith("Should not exceed staked amount");
  });

  it("Should stake/unstake ERC721", async function () {
    const tokenIdA = 1000,
      tokenIdB = 2000;
    await vCollectible.mintFor(userA.address, tokenIdA);
    await vCollectible.mintFor(userB.address, tokenIdB);

    // approve
    await vCollectible.connect(userA).approve(staking.address, tokenIdA);
    await vCollectible.connect(userB).approve(staking.address, tokenIdB);

    // stake
    await staking.connect(userA).stakeERC721(vCollectible.address, tokenIdA);
    expect(
      (await staking.userStaked(userA.address, vCollectible.address)).toNumber()
    ).to.be.equal(tokenIdA);
    expect(
      (await staking.totalStaked(vCollectible.address)).toNumber()
    ).to.be.equal(1);

    // unstake
    await staking.connect(userA).unstakeERC721(vCollectible.address, tokenIdA);
    expect(
      (await staking.userStaked(userA.address, vCollectible.address)).toNumber()
    ).to.be.equal(0);
    expect((await staking.totalStaked(vToken.address)).toNumber()).to.be.equal(
      0
    );

    // stake again with another user
    await staking.connect(userB).stakeERC721(vCollectible.address, tokenIdB);
    expect(
      (await staking.userStaked(userB.address, vCollectible.address)).toNumber()
    ).to.be.equal(tokenIdB);
    expect(
      (await staking.totalStaked(vCollectible.address)).toNumber()
    ).to.be.equal(1);

    // check if revert to unstake more tokens
    await expect(
      staking.connect(userA).unstakeERC721(vCollectible.address, tokenIdA)
    ).to.be.revertedWith("Should be staked ERC721");
  });

  it("Should lock/unlock", async function () {
    // approve
    await vToken
      .connect(userA)
      .approve(staking.address, ethers.constants.MaxUint256);
    await vToken
      .connect(userB)
      .approve(staking.address, ethers.constants.MaxUint256);

    // stake
    await staking.connect(userA).stakeERC20(vToken.address, 1000);
    await staking.connect(userB).stakeERC20(vToken.address, 2000);

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
      staking.connect(userA).unstakeERC20(vToken.address, 300)
    ).to.be.revertedWith("Should be unlocked");

    await staking.connect(locker).unlock(vToken.address);
    await staking.connect(locker).unlock(vToken.address);
    // await expect(
    //   staking.connect(locker).unlock(vToken.address)
    // ).to.be.revertedWith("Already unlocked");

    await expect(staking.connect(userA).unstakeERC20(vToken.address, 300)).to.be
      .not.reverted;
  });
});
