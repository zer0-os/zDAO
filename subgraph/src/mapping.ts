import {
  DAOCreated, DAODestroyed, LinkAdded, LinkRemoved
} from "../generated/ZDAORegistry/ZDAORegistry";
import { ZDAORecord, ZNAAssociation } from "../generated/schema";
import { Bytes, log, store } from "@graphprotocol/graph-ts";

function generateZDAORecordID(platformType: number, zDAOId: number): string {
  const id = `${platformType.toString()}-${zDAOId.toString()}`;
  return id;
}

export function handleDAOCreated(event: DAOCreated): void {
  const platformType = 0; // 0: Snapshot
  const zDAOId = event.params.daoId.toI32();
  const id = generateZDAORecordID(platformType, zDAOId);

  log.info("handleDAOCreated, called {}", [id]);

  const zDAO: ZDAORecord = new ZDAORecord(id);
  zDAO.id = id;
  zDAO.platformType = platformType;
  zDAO.zDAOId = zDAOId;
  zDAO.name = event.params.ensSpace;
  zDAO.gnosisSafe = event.params.gnosisSafe;
  zDAO.createdBy = Bytes.empty();
  zDAO.destroyed = false;
  zDAO.save();
}

export function handleDAODestroyed(event: DAODestroyed): void {
  const platformType = 0; // 0: Snapshot
  const zDAOId = event.params.daoId.toI32();
  const id = generateZDAORecordID(platformType, zDAOId);

  log.info("handleDAODestroyed, called {}", [id]);

  const zDAO: ZDAORecord | null = ZDAORecord.load(id);
  if (zDAO) {
    zDAO.destroyed = true;
    zDAO.save();
  } else {
    log.error("handleDAODestroyed, Unable to load ZDAORecord with zDAOId {}, {}", [
      id,
      event.block.number.toString()
    ]);
  }
}

export function handleLinkAdded(event: LinkAdded): void {
  const platformType = 0; // 0: Snapshot
  const zDAOId = event.params.daoId.toI32();
  const zDAORecordId = generateZDAORecordID(platformType, zDAOId);
  const zNAId = event.params.zNA.toHexString();

  log.info("handleLinkAdded, called {}, {}", [zDAORecordId, zNAId]);

  let zNAAssociation: ZNAAssociation | null = ZNAAssociation.load(zNAId);
  if (!zNAAssociation) {
    zNAAssociation = new ZNAAssociation(zNAId);
  }

  const zDAO: ZDAORecord | null = ZDAORecord.load(zDAORecordId);
  if (!zDAO) {
    log.error("handleLinkAdded, Unable to load ZDAORecord with zDAOId {}, {}", [
      zDAORecordId,
      event.block.number.toString()
    ]);
    return;
  }
  if (zDAO.destroyed) {
    log.error("handleLinkAdded, zDAO {} was already destroyed, {}", [
      zDAORecordId,
      event.block.number.toString()
    ]);
    return;
  }

  zNAAssociation.zDAORecord = zDAORecordId;
  zNAAssociation.save();
}

export function handleLinkRemoved(event: LinkRemoved): void {
  const platformType = 0; // 0: Snapshot
  const zDAOId = event.params.daoId.toI32();
  const zDAORecordId = generateZDAORecordID(platformType, zDAOId);
  const zNAId = event.params.zNA.toHexString();

  log.info("handleLinkRemoved, called {}, {}", [zDAORecordId, zNAId]);

  const zNAAssociation: ZNAAssociation | null = ZNAAssociation.load(zNAId);
  if (!zNAAssociation) {
    log.error("handleLinkRemoved, Unable to load associated zNA {}, {}", [
      zNAId,
      event.block.number.toString()
    ]);
    return;
  }
  
  const zDAO: ZDAORecord | null = ZDAORecord.load(zDAORecordId);
  if (!zDAO) {
    log.error("handleLinkRemoved, Unable to load ZDAORecord with zDAOId {}, {}", [
      zDAORecordId,
      event.block.number.toString()
    ]);
    return;
  }
  if (zDAO.destroyed) {
    log.error("handleLinkRemoved, zDAO {} was already destroyed, {}", [
      zDAORecordId,
      event.block.number.toString()
    ]);
    return;
  }

  store.remove('ZNAAssociation', zNAId);
}

export function handleProposalExecuted(event: ProposalExecuted): void {
  const platformType = event.params._platformType.toI32();
  const proposalHash = event.params._proposalHash;
  const token = event.params._token;
  const recipient = event.params._to;
  const amount = event.params._amount;

  log.info("handleProposalExecuted, called {}, {}", [platformType.toString(), proposalHash.toHexString()]);

  const id = `${platformType}-${proposalHash}`;
  const proposal: ExecutedProposal = new ExecutedProposal(id);
  proposal.platformType = platformType;
  proposal.proposalHash = proposalHash;
  proposal.token = token;
  proposal.recipient = recipient;
  proposal.amount = amount;
  proposal.save();
}