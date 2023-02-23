import { ethers } from "hardhat";

export const takeSnapshot = async () => {
  const result = await ethers.provider.send("evm_snapshot", []);
  await mineToBlock(1);
  return result;
};

export const restoreSnapshot = async (id: string) => {
  await ethers.provider.send("evm_revert", [id]);
  await mineToBlock(1);
};
