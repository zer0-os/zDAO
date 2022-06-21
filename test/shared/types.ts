export interface ZDAOConfig {
  token: string;
  amount: number;
  duration: number;
  votingThreshold: number;
  minimumVotingParticipants: number;
  minimumTotalVotingTokens: number;
  isRelativeMajority: boolean;
}

export interface ProposalConfig {
  ipfs: string;
}

export interface PolygonZDAOConfig {
  zDAOId: number;
  duration: number;
}

export interface PolyProposalConfig {
  proposalId: number;
  startTimestamp: number;
}
