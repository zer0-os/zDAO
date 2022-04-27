export interface ZDAOConfig {
  title: string;
  gnosisSafe: string;
  token: string;
  amount: number;
  isRelativeMajority: boolean;
  quorumVotes: number;
}

export interface ProposalConfig {
  startTimestamp: number;
  endTimestamp: number;
  target: string;
  value: number;
  data: string;
  ipfs: string;
}

export interface PolyZDAOConfig {
  zDAOId: number;
  mappedToken: string;
  isRelativeMajority: boolean;
  quorumVotes: number;
}

export interface PolyProposalConfig {
  proposalId: number;
  startTimestamp: number;
  endTimestamp: number;
}
