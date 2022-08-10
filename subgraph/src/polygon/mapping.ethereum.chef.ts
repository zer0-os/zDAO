import {
  DAOCreated,
  ProposalCalculated,
  ProposalCanceled,
  ProposalCreated,
} from "../../generated/EthereumZDAOChef/EthereumZDAOChef";
import { EthereumZDAO, EthereumProposal } from "../../generated/schema";
import { log } from "@graphprotocol/graph-ts";
import { PlatformType } from "../shared/config";
import {
  generateProposalId,
  generateZDAOID,
  generateZDAORecordID,
} from "../shared/utils";

export function handleDAOCreated(event: DAOCreated): void {
  const platformType = PlatformType.Polygon;
  const zDAOId = event.params._zDAOId.toI32();
  const zNA = event.params._zNA.toHexString();
  const createdBy = event.params._createdBy;
  const gnosisSafe = event.params._gnosisSafe;
  const token = event.params._token;
  const amount = event.params._amount;
  const duration = event.params._duration.toI32();
  const votingDelay = event.params._votingDelay.toI32();
  const votingThreshold = event.params._votingThreshold.toI32();
  const minimumVotingParticipants =
    event.params._minimumVotingParticipants.toI32();
  const minimumTotalVotingTokens = event.params._duration;

  log.info("handleDAOCreated, called {}, {}", [
    platformType.toString(),
    zDAOId.toString(),
  ]);

  const id = generateZDAOID(platformType, zDAOId);
  const zDAO: EthereumZDAO = new EthereumZDAO(id);
  zDAO.zDAORecord = generateZDAORecordID(platformType, zDAOId);
  zDAO.createdBy = createdBy;
  zDAO.gnosisSafe = gnosisSafe;
  zDAO.token = token;
  zDAO.amount = amount;
  zDAO.duration = duration;
  zDAO.votingDelay = votingDelay;
  zDAO.votingThreshold = votingThreshold;
  zDAO.minimumVotingParticipants = minimumVotingParticipants;
  zDAO.minimumTotalVotingTokens = minimumTotalVotingTokens;
  zDAO.destroyed = false;

  zDAO.save();
}

export function handleProposalCreated(event: ProposalCreated): void {
  const platformType = PlatformType.Polygon;
  const zDAOId = event.params._zDAOId.toI32();
  const proposalId = event.params._proposalId.toHexString();
  const numberOfChoices = event.params._numberOfChoices.toI32();
  const createdBy = event.params._createdBy;
  const snapshot = event.params._snapshot.toI32();

  log.info("handleProposalCreated, called {}, {}, {}", [
    platformType.toString(),
    zDAOId.toString(),
    proposalId,
  ]);

  const id = generateProposalId(platformType, zDAOId, proposalId);
  const proposal: EthereumProposal = new EthereumProposal(id);
  proposal.zDAO = generateZDAOID(platformType, zDAOId);
  proposal.proposalId = proposalId;
  proposal.numberOfChoices = numberOfChoices;
  proposal.createdBy = createdBy;
  proposal.snapshot = snapshot;
  proposal.canceled = false;
  proposal.calculated = false;
  proposal.save();
}

export function handleProposalCanceled(event: ProposalCanceled): void {
  const platformType = PlatformType.Polygon;
  const zDAOId = event.params._zDAOId.toI32();
  const proposalId = event.params._proposalId.toHexString();

  log.info("handleProposalCanceled, called {}, {}, {}", [
    platformType.toString(),
    zDAOId.toString(),
    proposalId,
  ]);

  const id = generateProposalId(platformType, zDAOId, proposalId);
  const proposal: EthereumProposal | null = EthereumProposal.load(id);
  if (!proposal) {
    log.error(
      "handleProposalCanceled, Unable to load Proposal {}, {}, {}, {}",
      [
        platformType.toString(),
        zDAOId.toString(),
        proposalId,
        event.block.number.toString(),
      ]
    );
    return;
  }
  proposal.canceled = true;
  proposal.save();
}

export function handleProposalCalculated(event: ProposalCalculated): void {
  const platformType = PlatformType.Polygon;
  const zDAOId = event.params._zDAOId.toI32();
  const proposalId = event.params._proposalId.toHexString();

  log.info("handleProposalCalculated, called {}, {}, {}", [
    platformType.toString(),
    zDAOId.toString(),
    proposalId,
  ]);

  const id = generateProposalId(platformType, zDAOId, proposalId);
  const proposal: EthereumProposal | null = EthereumProposal.load(id);
  if (!proposal) {
    log.error(
      "handleProposalCalculated, Unable to load Proposal {}, {}, {}, {}",
      [
        platformType.toString(),
        zDAOId.toString(),
        proposalId,
        event.block.number.toString(),
      ]
    );
    return;
  }
  if (proposal.canceled) {
    log.error(
      "handleProposalCalculated, Proposal was canceled {}, {}, {}, {}",
      [
        platformType.toString(),
        zDAOId.toString(),
        proposalId,
        event.block.number.toString(),
      ]
    );
    return;
  }
  proposal.calculated = true;
  proposal.save();
}
