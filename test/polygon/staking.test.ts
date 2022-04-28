import {
  MockContract,
  MockContractFactory,
  smock,
} from "@defi-wonderland/smock";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import chai, { expect } from "chai";
import { ethers } from "hardhat";
import { MockCollectibleUpgradeable__factory } from "../../types/factories/MockCollectibleUpgradeable__factory";
import { Staking__factory } from "../../types/factories/Staking__factory";
import { MockCollectibleUpgradeable } from "../../types/MockCollectibleUpgradeable";
import { Staking } from "../../types/Staking";
import {
  MockTokenUpgradeable,
  MockTokenUpgradeable__factory,
} from "../../types";
import { blockNumber, mineToBlock } from "../shared/utilities";

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

    const VotingTokenFactory = (await smock.mock<MockTokenUpgradeable__factory>(
      "MockTokenUpgradeable"
    )) as MockContractFactory<MockTokenUpgradeable__factory>;
    vToken =
      (await VotingTokenFactory.deploy()) as MockContract<MockTokenUpgradeable>;
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
    expect((await staking.totalStaked()).toNumber()).to.be.equal(1000);

    await mineToBlock(1);

    // unstake
    await staking.connect(userA).unstakeERC20(vToken.address, 300);
    expect(
      (await staking.userStaked(userA.address, vToken.address)).toNumber()
    ).to.be.equal(700);
    expect((await staking.totalStaked()).toNumber()).to.be.equal(700);

    await mineToBlock(1);

    // stake again with another user
    await staking.connect(userB).stakeERC20(vToken.address, 2000);
    expect(
      (await staking.userStaked(userB.address, vToken.address)).toNumber()
    ).to.be.equal(2000);
    expect((await staking.totalStaked()).toNumber()).to.be.equal(2700);

    await mineToBlock(1);

    // check if revert to unstake more tokens
    await expect(
      staking.connect(userA).unstakeERC20(vToken.address, 1000)
    ).to.be.revertedWith("Should not exceed staked amount");

    await mineToBlock(1);

    // check staking power
    expect((await staking.stakingPower(userA.address)).toNumber()).to.be.equal(
      700
    );
    expect((await staking.stakingPower(userB.address)).toNumber()).to.be.equal(
      2000
    );
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
    expect((await staking.totalStaked()).toNumber()).to.be.equal(1);

    await mineToBlock(1);

    // unstake
    await staking.connect(userA).unstakeERC721(vCollectible.address, tokenIdA);
    expect(
      (await staking.userStaked(userA.address, vCollectible.address)).toNumber()
    ).to.be.equal(0);
    expect((await staking.totalStaked()).toNumber()).to.be.equal(0);

    await mineToBlock(1);

    // stake again with another user
    await staking.connect(userB).stakeERC721(vCollectible.address, tokenIdB);
    expect(
      (await staking.userStaked(userB.address, vCollectible.address)).toNumber()
    ).to.be.equal(tokenIdB);
    expect((await staking.totalStaked()).toNumber()).to.be.equal(1);

    await mineToBlock(1);

    // check if revert to unstake more tokens
    await expect(
      staking.connect(userA).unstakeERC721(vCollectible.address, tokenIdA)
    ).to.be.revertedWith("Should be staked ERC721");

    // check staking power
    expect((await staking.stakingPower(userA.address)).toNumber()).to.be.equal(
      0
    );
    expect((await staking.stakingPower(userB.address)).toNumber()).to.be.equal(
      1
    );
  });

  it("Should get staking power according to block number", async function () {
    // approve
    await vToken
      .connect(userA)
      .approve(staking.address, ethers.constants.MaxUint256);
    await vToken
      .connect(userB)
      .approve(staking.address, ethers.constants.MaxUint256);

    await mineToBlock(1);

    // stake
    await staking.connect(userA).stakeERC20(vToken.address, 1000);
    await staking.connect(userB).stakeERC20(vToken.address, 2000);
    const block1 = await blockNumber();
    await mineToBlock(1);

    await staking.connect(userA).stakeERC20(vToken.address, 2000);
    const block2 = await blockNumber();
    await mineToBlock(1);

    await staking.connect(userA).stakeERC20(vToken.address, 3000);
    await staking.connect(userB).stakeERC20(vToken.address, 3000);
    const block3 = await blockNumber();
    await mineToBlock(1);

    await staking.connect(userA).stakeERC20(vToken.address, 4000);
    await staking.connect(userB).stakeERC20(vToken.address, 4000);
    const block4 = await blockNumber();
    await mineToBlock(1);

    const powerA = [
      [block1, 1000],
      [block2, 3000],
      [block3, 6000],
      [block4, 10000],
    ];
    const powerB = [
      [block1, 2000],
      [block2, 2000],
      [block3, 5000],
      [block4, 9000],
    ];

    expect((await staking.stakingPower(userA.address)).toNumber()).to.be.equal(
      10000
    );
    expect((await staking.stakingPower(userB.address)).toNumber()).to.be.equal(
      9000
    );

    for (const pair of powerA) {
      expect(
        (await staking.pastStakingPower(userA.address, pair[0])).toNumber()
      ).to.be.equal(pair[1]);
    }

    for (const pair of powerB) {
      expect(
        (await staking.pastStakingPower(userB.address, pair[0])).toNumber()
      ).to.be.equal(pair[1]);
    }
  });
});
