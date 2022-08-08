export interface ZDAOConfig {
  token: string;
  amount: number;
  duration: number;
  votingDelay: number;
  votingThreshold: number;
  minimumVotingParticipants: number;
  minimumTotalVotingTokens: number;
  isRelativeMajority: boolean;
}

export interface ProposalConfig {
  choices: string[];
  ipfs: string;
}

export interface PolygonZDAOConfig {
  zDAOId: number;
  duration: number;
  votingDelay: number;
}

export interface PolyProposalConfig {
  proposalId: number;
  numberOfChoices: number;
  startTimestamp: number;
}
