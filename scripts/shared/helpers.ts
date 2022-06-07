import { run } from "hardhat";
import { NomicLabsHardhatPluginError } from "hardhat/plugins";
import * as zns from "@zero-tech/zns-sdk";

export const sleep = (m: number) => new Promise((r) => setTimeout(r, m));

export const verifyContract = async (
  address: string,
  constructorArguments: any[] = []
) => {
  try {
    console.log("Sleeping for 10 seconds before verification...");
    await sleep(10000);
    console.log("\n>>>>>>>>>>>> Verification >>>>>>>>>>>>\n");

    console.log("Verifying: ", address);
    await run("verify:verify", {
      address,
      constructorArguments,
    });
  } catch (error) {
    if (
      error instanceof NomicLabsHardhatPluginError &&
      error.message.includes("Reason: Already Verified")
    ) {
      console.log("Already verified, skipping...");
    } else {
      console.error(error);
    }
  }
};

export const znsHash = (zna: string): string => {
  return zns.domains.domainNameToId(zna);
};
