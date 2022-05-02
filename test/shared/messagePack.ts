import { ethers } from "ethers";

enum MessageType {
  None = 0,
  CreateZDAO = 1,
  DeleteZDAO = 2,
  CreateProposal = 3,
  CancelProposal = 4,
  ExecuteProposal = 5,
  VoteResult = 6,
}

export interface CreateZDAOPack {
  lastZDAOId: number;
  token: string;
  isRelativeMajority: boolean;
  quorumVotes: string;
}

export const encodeCreateZDAO = (pack: CreateZDAOPack): string => {
  return ethers.utils.defaultAbiCoder.encode(
    ["uint256", "uint256", "address", "bool", "uint256"],
    [
      MessageType.CreateZDAO,
      pack.lastZDAOId,
      pack.token,
      pack.isRelativeMajority,
      pack.quorumVotes,
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
  duration: number;
}

export const encodeCreateProposal = (pack: CreateProposalPack): string => {
  return ethers.utils.defaultAbiCoder.encode(
    ["uint256", "uint256", "uint256", "uint256"],
    [MessageType.CreateProposal, pack.zDAOId, pack.proposalId, pack.duration]
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
