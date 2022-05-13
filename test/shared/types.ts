export interface ZDAOConfig {
  title: string;
  gnosisSafe: string;
  token: string;
  amount: number;
  votingThreshold: number;
  minimumVotingParticipants: number;
  minimumTotalVotingTokens: number;
  isRelativeMajority: boolean;
}

export interface ProposalConfig {
  duration: number;
  target: string;
  value: number;
  data: string;
  ipfs: string;
}

export interface PolyZDAOConfig {
  zDAOId: number;
}

export interface PolyProposalConfig {
  proposalId: number;
  startTimestamp: number;
  endTimestamp: number;
}
