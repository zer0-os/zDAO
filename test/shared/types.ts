export interface ZDAOConfig {
  name: string;
  gnosisSafe: string;
  token: string;
  amount: number;
  minPeriod: number;
  isRelativeMajority: boolean;
  threshold: number;
}

export interface ProposalConfig {
  startTimestamp: number;
  endTimestamp: number;
  token: string;
  amount: number;
  ipfs: string;
}

export interface PolyZDAOConfig {
  zDAOId: number;
  mappedToken: string;
  isRelativeMajority: boolean;
  threshold: number;
}

export interface PolyProposalConfig {
  proposalId: number;
  startTimestamp: number;
  endTimestamp: number;
}
