import {
  CastVote,
  DAOCreated,
  ProposalCalculated,
  ProposalCanceled,
  ProposalCreated,
} from "../../generated/PolygonZDAOChef/PolygonZDAOChef";
import {
  PolygonZDAO,
  PolygonProposal,
  PolygonVote,
} from "../../generated/schema";
import { BigInt, log } from "@graphprotocol/graph-ts";
import { PlatformType } from "../shared/config";
import {
  generateProposalId,
  generateVoteId,
  generateZDAOID,
} from "../shared/utils";

export function handleDAOCreated(event: DAOCreated): void {
  const platformType = PlatformType.Polygon;
  const zDAOId = event.params._zDAOId.toI32();
  const token = event.params._token;
  const duration = event.params._duration.toI32();
  const votingDelay = event.params._votingDelay.toI32();

  log.info("handleDAOCreated, called {}, {}", [
    platformType.toString(),
    zDAOId.toString(),
  ]);

  const id = generateZDAOID(platformType, zDAOId);
  const zDAO: PolygonZDAO = new PolygonZDAO(id);
  zDAO.platformType = platformType;
  zDAO.zDAOId = zDAOId;
  zDAO.token = token;
  zDAO.duration = duration;
  zDAO.votingDelay = votingDelay;
  zDAO.snapshot = event.block.number.toI32();
  zDAO.destroyed = false;

  zDAO.save();
}

export function handleProposalCreated(event: ProposalCreated): void {
  const platformType = PlatformType.Polygon;
  const zDAOId = event.params._zDAOId.toI32();
  const proposalId = event.params._proposalId.toHexString();
  const numberOfChoices = event.params._numberOfChoices.toI32();
  const proposalCreated = event.params._proposalCreated.toI32();
  const currentTimestamp = event.params._currentTimestamp.toI32();

  log.info("handleProposalCreated, called {}, {}, {}", [
    platformType.toString(),
    zDAOId.toString(),
    proposalId,
  ]);

  const zId = generateZDAOID(platformType, zDAOId);
  const zDAO: PolygonZDAO | null = PolygonZDAO.load(zId);
  if (!zDAO) {
    log.error("handleProposalCreated, Unable to load zDAO {}, {}, {}", [
      platformType.toString(),
      zDAOId.toString(),
      event.block.number.toString(),
    ]);
    return;
  }

  const id = generateProposalId(platformType, zDAOId, proposalId);
  const proposal: PolygonProposal = new PolygonProposal(id);
  proposal.zDAO = zId;
  proposal.proposalId = proposalId;
  proposal.numberOfChoices = numberOfChoices;
  proposal.startTimestamp =
    proposalCreated + zDAO.votingDelay > currentTimestamp
      ? proposalCreated + zDAO.votingDelay
      : currentTimestamp;
  proposal.endTimestamp = proposal.startTimestamp + zDAO.duration;
  proposal.snapshot = event.block.number.toI32();
  proposal.canceled = false;
  proposal.calculated = false;
  const sumOfVotes = new Array<BigInt>(proposal.numberOfChoices);
  for (let i = 0; i < proposal.numberOfChoices; i++) {
    sumOfVotes[i] = BigInt.fromI32(0);
  }
  proposal.sumOfVotes = sumOfVotes;
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
  const proposal: PolygonProposal | null = PolygonProposal.load(id);
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
  const proposal: PolygonProposal | null = PolygonProposal.load(id);
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
  proposal.calculatedTx = event.transaction.hash;
  proposal.save();
}

export function handleCastVote(event: CastVote): void {
  const platformType = PlatformType.Polygon;
  const zDAOId = event.params._zDAOId.toI32();
  const proposalId = event.params._proposalId.toHexString();
  const voter = event.params._voter;
  const choice = event.params._choice.toI32();
  const votingPower = event.params._votingPower;

  log.info("handleCastVote, called {}, {}, {}", [
    platformType.toString(),
    zDAOId.toString(),
    proposalId,
  ]);

  const pId = generateProposalId(platformType, zDAOId, proposalId);
  const proposal: PolygonProposal | null = PolygonProposal.load(pId);
  if (!proposal) {
    log.error("handleCastVote, Unable to load Proposal {}, {}, {}, {}", [
      platformType.toString(),
      zDAOId.toString(),
      proposalId,
      event.block.number.toString(),
    ]);
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

  const id = generateVoteId(
    platformType,
    zDAOId,
    proposalId,
    voter.toHexString()
  );
  let vote: PolygonVote | null = PolygonVote.load(id);
  let lastChoice: i32 = -1;
  if (!vote) {
    vote = new PolygonVote(id);
    proposal.voters++;
  } else {
    lastChoice = vote.choice;
  }
  vote.proposal = pId;
  vote.voter = voter;
  vote.choice = choice;
  vote.votingPower = votingPower;
  vote.save();

  const sumOfVotes = proposal.sumOfVotes;
  if (lastChoice >= 0) {
    sumOfVotes[lastChoice] = sumOfVotes[lastChoice].minus(votingPower);
  }
  sumOfVotes[choice - 1] = sumOfVotes[choice - 1].plus(votingPower);
  proposal.sumOfVotes = sumOfVotes;
  proposal.save();
}
