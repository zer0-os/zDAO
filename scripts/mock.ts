import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import * as zns from "@zero-tech/zns-sdk";
import { ethers, network, upgrades } from "hardhat";
import { MockTokenUpgradeable, MockZNSHub, VotingToken } from "../types";
import { config, znsHubConfig } from "./shared/config";
import { verifyContract } from "./shared/helpers";

const deployZNSHub = async (deployer: SignerWithAddress) => {
  // MockZNSHub
  console.log("Deploying MockZNSHub contract...");
  const MockZNSHubFactory = await ethers.getContractFactory("MockZNSHub");
  const mockZNSHub = (await MockZNSHubFactory.deploy()) as MockZNSHub;
  await mockZNSHub.deployed();
  console.log(`\ndeployed: ${mockZNSHub.address}`);

  await verifyContract(mockZNSHub.address);

  console.table([
    {
      Label: "Deployer address",
      Info: deployer.address,
    },
    {
      Label: "MockZNSHub address",
      Info: mockZNSHub.address,
    },
  ]);

  console.log("\nInitializing contracts");
  console.log("Initializing MockZNSHub contract...");
  for (const item of znsHubConfig) {
    console.log(`> owning ${item.domain} to ${item.owner}`);
    const domainId = zns.domains.domainNameToId(item.domain);
    await mockZNSHub.addZNAOwner(domainId, item.owner);
  }
};

const deployVotingToken = async (deployer: SignerWithAddress) => {
  // VotingToken
  console.log("Deploying VotingToken contract...");
  const MockTokenUpgradeableFactory = await ethers.getContractFactory(
    "MockTokenUpgradeable"
  );
  const mockTokenUpgradeable = (await upgrades.deployProxy(
    MockTokenUpgradeableFactory,
    ["DAOToken", "DAOToken"],
    {
      kind: "uups",
      initializer: "__MockTokenUpgradeable_init",
    }
  )) as MockTokenUpgradeable;
  await mockTokenUpgradeable.deployed();
  console.log(`\ndeployed: ${mockTokenUpgradeable.address}`);

  const votingTokenImpl = await upgrades.erc1967.getImplementationAddress(
    mockTokenUpgradeable.address
  );
  await verifyContract(votingTokenImpl);

  console.table([
    {
      Label: "Deployer address",
      Info: deployer.address,
    },
    {
      Label: "VotingToken proxy address",
      Info: mockTokenUpgradeable.address,
    },
    {
      Label: "VotingToken implementation address",
      Info: votingTokenImpl,
    },
  ]);
};

const main = async () => {
  const signers = await ethers.getSigners();
  if (signers.length < 1) {
    throw new Error(`Not found deployer`);
  }

  const deployer: SignerWithAddress = signers[0];

  if (network.name === "goerli") {
    // await deployZNSHub(deployer);

    console.log("\n\nWelcome Mockup!");
  }

  if (network.name === "goerli" || network.name === "polygonMumbai") {
    await deployVotingToken(deployer);

    console.log("\n\nWelcome Mockup!");
  }
};

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
