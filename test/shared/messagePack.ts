import { ethers } from "ethers";

enum MessageType {
  None = 0,
  CreateZDAO = 1,
  DeleteZDAO = 2,
  CreateProposal = 3,
  CancelProposal = 4,
  ExecuteProposal = 5,
  CalculateProposal = 6,
}

export interface CreateZDAOPack {
  lastZDAOId: number;
  duration: number;
  token: string;
}

export const encodeCreateZDAO = (pack: CreateZDAOPack): string => {
  return ethers.utils.defaultAbiCoder.encode(
    ["uint256", "uint256", "uint256", "uint256"],
    [MessageType.CreateZDAO, pack.lastZDAOId, pack.duration, pack.token]
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
}

export const encodeCreateProposal = (pack: CreateProposalPack): string => {
  return ethers.utils.defaultAbiCoder.encode(
    ["uint256", "uint256", "uint256"],
    [MessageType.CreateProposal, pack.zDAOId, pack.proposalId]
  );
};

export interface CalculateProposalPack {
  zDAOId: number;
  proposalId: number;
  voters: number;
  yes: number;
  no: number;
}

export const encodeCalculateProposal = (
  pack: CalculateProposalPack
): string => {
  return ethers.utils.defaultAbiCoder.encode(
    ["uint256", "uint256", "uint256", "uint256", "uint256", "uint256"],
    [
      MessageType.CalculateProposal,
      pack.zDAOId,
      pack.proposalId,
      pack.voters,
      pack.yes,
      pack.no,
    ]
  );
};
