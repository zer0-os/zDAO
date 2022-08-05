import { BigNumber } from "ethers";
/* eslint-disable no-console */
/* eslint-disable @typescript-eslint/no-extra-semi */
import chai from "chai";
import { solidity } from "ethereum-waffle";
import { expect } from "chai";
import { ethers } from "hardhat";
import {MockContract, smock, MockContractFactory} from "@defi-wonderland/smock";

import { ZDAOModule } from "../types/ZDAOModule";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ZDAOModule__factory } from "../types/factories/ZDAOModule__factory";
import { MockGnosisSafeProxy } from "../types/MockGnosisSafeProxy";
import { MockGnosisSafeProxy__factory } from "../types/factories/MockGnosisSafeProxy__factory";
import { MockToken } from "../types/MockToken";

chai.use(solidity);

describe("ZDAOModule", function () {
  let deployer: SignerWithAddress, owner: SignerWithAddress, executor: SignerWithAddress, userA: SignerWithAddress;
  
  let zDAOModule: MockContract<ZDAOModule>, gnosisSafeProxy: MockContract<MockGnosisSafeProxy>, mockToken: MockToken;

  beforeEach(async function () {
    [deployer, owner, executor, userA] = await ethers.getSigners();

    const MockGnosisSafeProxyFactory = (await smock.mock<MockGnosisSafeProxy__factory>("MockGnosisSafeProxy")) as MockContractFactory<MockGnosisSafeProxy__factory>;
    gnosisSafeProxy = (await MockGnosisSafeProxyFactory.deploy()) as MockContract<MockGnosisSafeProxy>;

    const MockTokenFactory = await ethers.getContractFactory("MockToken");
    mockToken = await MockTokenFactory.deploy(BigNumber.from(10).pow(18).mul(100000)) as MockToken;

    const ZDAOModuleFactory = (await smock.mock<ZDAOModule__factory>(
      "ZDAOModule"
    )) as MockContractFactory<ZDAOModule__factory>;
    zDAOModule =
      (await ZDAOModuleFactory.deploy()) as MockContract<ZDAOModule>;
    await zDAOModule.__ZDAOModule_init(
      gnosisSafeProxy.address,
      deployer.address
    );

    await gnosisSafeProxy.enableModule(zDAOModule.address);

    // fund tokens
    await mockToken.transfer(gnosisSafeProxy.address, await mockToken.totalSupply());
    await userA.sendTransaction({
      to: gnosisSafeProxy.address,
      value: BigNumber.from(10).pow(18).mul(1000)
    });
  });

  it("Only callable by Gnosis Safe", async function () {
    await expect(zDAOModule.connect(deployer).executeProposal(0, "ProposalId", mockToken.address, userA.address, 100000)).to.be.revertedWith("Only callable by GnosisSafe");

    await zDAOModule.setVariable("avatar", executor.address);

    await expect(zDAOModule.connect(executor).executeProposal(0, "ProposalId", mockToken.address, userA.address, 100000)).to.be.not.reverted;
  });

  it("Should transfer ERC20", async function () {
    const balanceBefore = await mockToken.balanceOf(userA.address);

    await zDAOModule.setVariable("avatar", executor.address);

    const amount = 100000;
    await zDAOModule.connect(executor).executeProposal(0, "ProposalId", mockToken.address, userA.address, amount);

    const balanceAfter = await mockToken.balanceOf(userA.address);
    expect(balanceAfter.sub(balanceBefore)).to.be.equal(amount);
  });

  it("Should transfer ETH", async function () {
    const balanceBefore = await userA.getBalance();

    await zDAOModule.setVariable("avatar", executor.address);

    const amount = 100000;
    await zDAOModule.connect(executor).executeProposal(0, "ProposalId", ethers.constants.AddressZero, userA.address, amount);

    const balanceAfter = await userA.getBalance();
    expect(balanceAfter.sub(balanceBefore)).to.be.equal(amount);
  });

  it("Proposal should be executed", async function () {
    await zDAOModule.setVariable("avatar", executor.address);

    const amount = 100000;
    await zDAOModule.connect(executor).executeProposal(0, "ProposalId", ethers.constants.AddressZero, userA.address, amount);

    const isExecuted = await zDAOModule.isProposalExecuted(0, "ProposalId");
    expect(isExecuted).to.be.equal(true);
  });
});
