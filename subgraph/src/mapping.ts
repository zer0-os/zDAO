import {
  DAOCreated, DAODestroyed, LinkAdded, LinkRemoved
} from "../generated/ZDAORegistry/ZDAORegistry";
import {
  ProposalExecuted
} from "../generated/ZDAOModule/ZDAOModule";
import { ZDAORecord, ZNAAssociation, ExecutedProposal } from "../generated/schema";
import { log, store } from "@graphprotocol/graph-ts";

export function handleDAOCreated(event: DAOCreated): void {
  const zDAOId = event.params.daoId.toString();

  log.info("handleDAOCreated, called {}", [zDAOId]);

  const zDAO: ZDAORecord = new ZDAORecord(zDAOId);
  zDAO.id = zDAOId;
  zDAO.ensSpace = event.params.ensSpace;
  zDAO.gnosisSafe = event.params.gnosisSafe;
  zDAO.destroyed = false;
  zDAO.save();
}

export function handleDAODestroyed(event: DAODestroyed): void {
  const zDAOId = event.params.daoId.toString();

  log.info("handleDAODestroyed, called {}", [zDAOId]);

  const zDAO: ZDAORecord | null = ZDAORecord.load(zDAOId);
  if (zDAO) {
    zDAO.destroyed = true;
    zDAO.save();
  } else {
    log.error("handleDAODestroyed, Unable to load ZDAORecord with zDAOId {}, {}", [
      zDAOId,
      event.block.number.toString()
    ]);
  }
}

export function handleLinkAdded(event: LinkAdded): void {
  const zDAOId = event.params.daoId.toString();
  const zNAId = event.params.zNA.toHexString();

  log.info("handleLinkAdded, called {}, {}", [zDAOId, zNAId]);

  let zNAAssociation: ZNAAssociation | null = ZNAAssociation.load(zNAId);
  if (!zNAAssociation) {
    zNAAssociation = new ZNAAssociation(zNAId);
  }

  const zDAO: ZDAORecord | null = ZDAORecord.load(zDAOId);
  if (!zDAO) {
    log.error("handleLinkAdded, Unable to load ZDAORecord with zDAOId {}, {}", [
      zDAOId,
      event.block.number.toString()
    ]);
    return;
  }
  if (zDAO.destroyed) {
    log.error("handleLinkAdded, zDAO {} was already destroyed, {}", [
      zDAOId,
      event.block.number.toString()
    ]);
    return;
  }

  zNAAssociation.zDAORecord = zDAOId;
  zNAAssociation.save();
}

export function handleLinkRemoved(event: LinkRemoved): void {
  const zDAOId = event.params.daoId.toString();
  const zNAId = event.params.zNA.toHexString();

  log.info("handleLinkRemoved, called {}, {}", [zDAOId, zNAId]);

  const zNAAssociation: ZNAAssociation | null = ZNAAssociation.load(zNAId);
  if (!zNAAssociation) {
    log.error("handleLinkRemoved, Unable to load associated zNA {}, {}", [
      zNAId,
      event.block.number.toString()
    ]);
    return;
  }
  
  const zDAO: ZDAORecord | null = ZDAORecord.load(zDAOId);
  if (!zDAO) {
    log.error("handleLinkRemoved, Unable to load ZDAORecord with zDAOId {}, {}", [
      zDAOId,
      event.block.number.toString()
    ]);
    return;
  }
  if (zDAO.destroyed) {
    log.error("handleLinkRemoved, zDAO {} was already destroyed, {}", [
      zDAOId,
      event.block.number.toString()
    ]);
    return;
  }

  store.remove('ZNAAssociation', zNAId);
}

export function handleProposalExecuted(event: ProposalExecuted): void {
  const platformType = event.params._platformType.toI32();
  const proposalId = event.params._proposalId.toString();
  const token = event.params._token;
  const recipient = event.params._to;
  const amount = event.params._amount;

  log.info("handleProposalExecuted, called {}, {}", [platformType.toString(), proposalId]);

  const id = `${platformType}-${proposalId}`;
  const proposal: ExecutedProposal = new ExecutedProposal(id);
  proposal.platformType = platformType;
  proposal.proposalId = proposalId;
  proposal.token = token;
  proposal.recipient = recipient;
  proposal.amount = amount;
  proposal.save();
}