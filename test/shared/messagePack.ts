import { ethers } from "ethers";

enum MessageType {
  CreateZDAO = 1,
  DeleteZDAO = 2,
  CreateProposal = 3,
  VoteResult = 4,
}

export interface CreateZDAOPack {
  lastZDAOId: number;
  name: string;
  zDAOOwner: string;
  token: string;
  isRelativeMajority: boolean;
  threshold: number;
}

export const encodeCreateZDAO = (pack: CreateZDAOPack): string => {
  return ethers.utils.defaultAbiCoder.encode(
    ["uint256", "uint256", "string", "address", "address", "bool", "uint256"],
    [
      MessageType.CreateZDAO,
      pack.lastZDAOId,
      pack.name,
      pack.zDAOOwner,
      pack.token,
      pack.isRelativeMajority,
      pack.threshold,
    ]
  );
};

export interface DeleteZDAOPack {
  zDAOId: number;
}

export const encodeDeleteZDAO = (pack: DeleteZDAOPack): string => {
  return ethers.utils.defaultAbiCoder.encode(
    ["uint256", "uint256"],
    [MessageType.DeleteZDAO, pack.zDAOId]
  );
};

export interface CreateProposalPack {
  zDAOId: number;
  proposalId: number;
  createdBy: string;
  startTimestamp: number;
  endTimestamp: number;
  token: string;
  amount: number;
  ipfs: string;
}

export const encodeCreateProposal = (pack: CreateProposalPack): string => {
  return ethers.utils.defaultAbiCoder.encode(
    [
      "uint256",
      "uint256",
      "uint256",
      "address",
      "uint256",
      "uint256",
      "address",
      "uint256",
      "bytes32",
    ],
    [
      MessageType.CreateProposal,
      pack.zDAOId,
      pack.proposalId,
      pack.createdBy,
      pack.startTimestamp,
      pack.endTimestamp,
      pack.token,
      pack.amount,
      pack.ipfs,
    ]
  );
};

export interface VoteResultPack {
  zDAOId: number;
  proposalId: number;
  yes: number;
  no: number;
}

export const encodeVoteResult = (pack: VoteResultPack): string => {
  return ethers.utils.defaultAbiCoder.encode(
    ["uint256", "uint256", "uint256", "uint256", "uint256"],
    [MessageType.VoteResult, pack.zDAOId, pack.proposalId, pack.yes, pack.no]
  );
};
