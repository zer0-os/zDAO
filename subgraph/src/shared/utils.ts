export function generateZDAORecordID(
  platformType: number,
  zDAOId: number
): string {
  const id = `${platformType.toString()}-${zDAOId.toString()}`;
  return id;
}

export function generateZDAOID(platformType: number, zDAOId: number): string {
  const id = `${platformType.toString()}-${zDAOId.toString()}`;
  return id;
}

export function generateProposalId(
  platformType: number,
  zDAOId: number,
  proposalId: string
): string {
  const id = `${platformType.toString()}-${zDAOId.toString()}-${proposalId}`;
  return id;
}

export function generateVoteId(
  platformType: number,
  zDAOId: number,
  proposalId: string,
  voter: string
): string {
  const id = `${platformType.toString()}-${zDAOId.toString()}-${proposalId}-${voter}`;
  return id;
}
