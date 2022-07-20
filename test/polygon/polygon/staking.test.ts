import {
  FakeContract,
  MockContract,
  MockContractFactory,
  smock,
} from "@defi-wonderland/smock";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import chai, { expect } from "chai";
import { ethers } from "hardhat";
import { MockCollectibleUpgradeable__factory } from "../../../types/factories/MockCollectibleUpgradeable__factory";
import { Staking__factory } from "../../../types/factories/Staking__factory";
import { MockCollectibleUpgradeable } from "../../../types/MockCollectibleUpgradeable";
import { Staking } from "../../../types/Staking";
import {
  IChildChainManager,
  MockTokenUpgradeable,
  MockTokenUpgradeable__factory,
} from "../../../types";
import { blockNumber, mineToBlock } from "../../shared/utilities";
import { BigNumber } from "ethers";

chai.use(smock.matchers);

describe("Staking", async function () {
  let owner: SignerWithAddress,
    locker: SignerWithAddress,
    userA: SignerWithAddress,
    userB: SignerWithAddress;

  let staking: MockContract<Staking>,
    childChainManager: FakeContract<IChildChainManager>,
    vToken: MockContract<MockTokenUpgradeable>,
    vCollectible: MockContract<MockCollectibleUpgradeable>;

  let BIG_POW: BigNumber;

  beforeEach("init setup", async function () {
    [owner, locker, userA, userB] = await ethers.getSigners();

    childChainManager = (await smock.fake(
      "IChildChainManager"
    )) as FakeContract<IChildChainManager>;

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

    BIG_POW = BigNumber.from(10).pow(18);

    const MockCollectibleUpgradeableFactory =
      (await smock.mock<MockCollectibleUpgradeable__factory>(
        "MockCollectibleUpgradeable"
      )) as MockContractFactory<MockCollectibleUpgradeable__factory>;
    vCollectible =
      (await MockCollectibleUpgradeableFactory.deploy()) as MockContract<MockCollectibleUpgradeable>;
    await vCollectible.__MockCollectibleUpgradeable_init("vCollectible", "VC");

    await vToken.mintFor(userA.address, BigNumber.from(10000000).mul(BIG_POW));
    await vToken.mintFor(userB.address, BigNumber.from(10000000).mul(BIG_POW));
  });

  it("Should stake/unstake ERC20", async function () {
    // approve
    await vToken
      .connect(userA)
      .approve(staking.address, ethers.constants.MaxUint256);
    await vToken
      .connect(userB)
      .approve(staking.address, ethers.constants.MaxUint256);

    childChainManager.childToRootToken
      .whenCalledWith(vToken.address)
      .returns(vToken.address);

    // stake
    await staking
      .connect(userA)
      .stakeERC20(vToken.address, BigNumber.from(1000).mul(BIG_POW));
    expect(
      await staking.stakingPower(userA.address, vToken.address)
    ).to.be.equal(BigNumber.from(1000).mul(BIG_POW));

    await mineToBlock(1);

    // unstake
    await staking
      .connect(userA)
      .unstakeERC20(vToken.address, BigNumber.from(300).mul(BIG_POW));
    expect(
      await staking.stakingPower(userA.address, vToken.address)
    ).to.be.equal(BigNumber.from(700).mul(BIG_POW));

    await mineToBlock(1);

    // stake again with another user
    await staking
      .connect(userB)
      .stakeERC20(vToken.address, BigNumber.from(2000).mul(BIG_POW));
    expect(
      await staking.stakingPower(userB.address, vToken.address)
    ).to.be.equal(BigNumber.from(2000).mul(BIG_POW));

    await mineToBlock(1);

    // check if revert to unstake more tokens
    await expect(
      staking
        .connect(userA)
        .unstakeERC20(vToken.address, BigNumber.from(1000).mul(BIG_POW))
    ).to.be.revertedWith("Should not exceed staked amount");

    await mineToBlock(1);

    // check staking power
    expect(
      await staking.stakingPower(userA.address, vToken.address)
    ).to.be.equal(BigNumber.from(700).mul(BIG_POW));
    expect(
      await staking.stakingPower(userB.address, vToken.address)
    ).to.be.equal(BigNumber.from(2000).mul(BIG_POW));
  });

  it("Should stake/unstake ERC721", async function () {
    const tokenIdA = 1000,
      tokenIdB = 2000,
      tokenIdC = 3000;
    await vCollectible.mintFor(userA.address, tokenIdA);
    await vCollectible.mintFor(userB.address, tokenIdB);
    await vCollectible.mintFor(userB.address, tokenIdC);

    childChainManager.childToRootToken
      .whenCalledWith(vCollectible.address)
      .returns(vCollectible.address);

    // approve
    await vCollectible.connect(userA).approve(staking.address, tokenIdA);
    await vCollectible.connect(userB).approve(staking.address, tokenIdB);
    await vCollectible.connect(userB).approve(staking.address, tokenIdC);

    // stake
    await staking.connect(userA).stakeERC721(vCollectible.address, tokenIdA);
    expect(
      (
        await staking.stakingPower(userA.address, vCollectible.address)
      ).toNumber()
    ).to.be.equal(1);

    await mineToBlock(1);

    // unstake
    await staking.connect(userA).unstakeERC721(vCollectible.address, tokenIdA);
    expect(
      (
        await staking.stakingPower(userA.address, vCollectible.address)
      ).toNumber()
    ).to.be.equal(0);

    await mineToBlock(1);

    // stake again with another user
    await staking.connect(userB).stakeERC721(vCollectible.address, tokenIdB);
    expect(
      (
        await staking.stakingPower(userB.address, vCollectible.address)
      ).toNumber()
    ).to.be.equal(1);
    await staking.connect(userB).stakeERC721(vCollectible.address, tokenIdC);
    expect(
      (
        await staking.stakingPower(userB.address, vCollectible.address)
      ).toNumber()
    ).to.be.equal(2);

    await mineToBlock(1);

    // check if revert to unstake more tokens
    await expect(
      staking.connect(userA).unstakeERC721(vCollectible.address, tokenIdA)
    ).to.be.revertedWith("Should be staked ERC721");

    // check staking power
    expect(
      (
        await staking.stakingPower(userA.address, vCollectible.address)
      ).toNumber()
    ).to.be.equal(0);
    expect(
      (
        await staking.stakingPower(userB.address, vCollectible.address)
      ).toNumber()
    ).to.be.equal(2);
  });

  it("Should revert stake ERC20 with ERC721 address", async function () {
    const tokenIdA = 1000;
    await vCollectible.mintFor(userA.address, tokenIdA);

    childChainManager.childToRootToken
      .whenCalledWith(vCollectible.address)
      .returns(vCollectible.address);

    // approve
    await vCollectible.connect(userA).approve(staking.address, tokenIdA);

    await expect(
      staking.connect(userA).stakeERC20(vCollectible.address, BigNumber.from(1))
    ).to.be.reverted;

    expect(
      (
        await staking.stakingPower(userA.address, vCollectible.address)
      ).toNumber()
    ).to.be.equal(0);
  });

  it("Should get staking power according to block number", async function () {
    // approve
    await vToken
      .connect(userA)
      .approve(staking.address, ethers.constants.MaxUint256);
    await vToken
      .connect(userB)
      .approve(staking.address, ethers.constants.MaxUint256);

    childChainManager.childToRootToken
      .whenCalledWith(vToken.address)
      .returns(vToken.address);

    await mineToBlock(1);

    // stake
    await staking
      .connect(userA)
      .stakeERC20(vToken.address, BigNumber.from(1000).mul(BIG_POW));
    await staking
      .connect(userB)
      .stakeERC20(vToken.address, BigNumber.from(2000).mul(BIG_POW));
    const block1 = await blockNumber();
    await mineToBlock(1);

    await staking
      .connect(userA)
      .stakeERC20(vToken.address, BigNumber.from(2000).mul(BIG_POW));
    const block2 = await blockNumber();
    await mineToBlock(1);

    await staking
      .connect(userA)
      .stakeERC20(vToken.address, BigNumber.from(3000).mul(BIG_POW));
    await staking
      .connect(userB)
      .stakeERC20(vToken.address, BigNumber.from(3000).mul(BIG_POW));
    const block3 = await blockNumber();
    await mineToBlock(1);

    await staking
      .connect(userA)
      .stakeERC20(vToken.address, BigNumber.from(4000).mul(BIG_POW));
    await staking
      .connect(userB)
      .stakeERC20(vToken.address, BigNumber.from(4000).mul(BIG_POW));
    const block4 = await blockNumber();
    await mineToBlock(1);

    const powerA = [
      [block1, BigNumber.from(1000).mul(BIG_POW)],
      [block2, BigNumber.from(3000).mul(BIG_POW)],
      [block3, BigNumber.from(6000).mul(BIG_POW)],
      [block4, BigNumber.from(10000).mul(BIG_POW)],
    ];
    const powerB = [
      [block1, BigNumber.from(2000).mul(BIG_POW)],
      [block2, BigNumber.from(2000).mul(BIG_POW)],
      [block3, BigNumber.from(5000).mul(BIG_POW)],
      [block4, BigNumber.from(9000).mul(BIG_POW)],
    ];

    expect(
      await staking.stakingPower(userA.address, vToken.address)
    ).to.be.equal(BigNumber.from(10000).mul(BIG_POW));
    expect(
      await staking.stakingPower(userB.address, vToken.address)
    ).to.be.equal(BigNumber.from(9000).mul(BIG_POW));

    for (const pair of powerA) {
      expect(
        await staking.pastStakingPower(userA.address, vToken.address, pair[0])
      ).to.be.equal(pair[1]);
    }

    for (const pair of powerB) {
      expect(
        await staking.pastStakingPower(userB.address, vToken.address, pair[0])
      ).to.be.equal(pair[1]);
    }
  });
});
