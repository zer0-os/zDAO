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
  target: string;
  value: number;
  data: string;
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
