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
  name: string;
  owner: string;
  token: string;
  mappedToken: string;
  isRelativeMajority: boolean;
  threshold: number;
}

export interface PolyProposalConfig extends ProposalConfig {
  proposalId: number;
  createdBy: string;
}
