export interface ZDAOConfig {
  title: string;
  gnosisSafe: string;
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

export interface PolyZDAOConfig {
  zDAOId: number;
  duration: number;
}

export interface PolyProposalConfig {
  proposalId: number;
  startTimestamp: number;
}
