import {
  DAOCreated, DAODestroyed, LinkAdded, LinkRemoved
} from "../generated/ZDAORegistry/ZDAORegistry";
import { ZDAORecord, ZNAAssociation } from "../generated/schema";
import { log } from "@graphprotocol/graph-ts";

export function handleDAOCreated(event: DAOCreated): void {
  const id = event.params.daoId.toString();
  log.info("handleDAOCreated, called {}", [id]);

  const zDAO: ZDAORecord = new ZDAORecord(event.params.daoId.toString());
  zDAO.id = event.params.daoId.toString();
  zDAO.zDAOId = event.params.daoId.toI32();
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
  const zNA = event.params.zNA;

  log.info("handleLinkAdded, called {}, {}", [zDAOId, zNA.toHexString()]);

  const associationId = zNA.toHexString().concat('-').concat(zDAOId);
  let zNAAssociation: ZNAAssociation | null = ZNAAssociation.load(associationId);
  if (zNAAssociation) {
    log.error("handleLinkAdded, zNA {} was already added association with zDAO {}, {}", [
      zNA.toHexString(),
      zDAOId,
      event.block.number.toString()
    ]);
    return;
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

  zNAAssociation = new ZNAAssociation(associationId);
  zNAAssociation.zNA = zNA;
  zNAAssociation.zDAORecord = zDAOId;
  zNAAssociation.save();
}

export function handleLinkRemoved(event: LinkRemoved): void {
  const zDAOId = event.params.daoId.toString();
  const zNA = event.params.zNA;

  log.info("handleLinkRemoved, called {}, {}", [zDAOId, zNA.toHexString()]);

  const associationId = zNA.toHexString().concat('-').concat(zDAOId);
  const zNAAssociation: ZNAAssociation | null = ZNAAssociation.load(associationId);
  if (!zNAAssociation) {
    log.error("handleLinkRemoved, Unable to load associated zNA {}, {}", [
      zNA.toHexString(),
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

  zNAAssociation.zDAORecord = '';
  zNAAssociation.save();
}
