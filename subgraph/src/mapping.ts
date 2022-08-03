import {
  DAOCreated, DAODestroyed, LinkAdded, LinkRemoved
} from "../generated/ZDAORegistry/ZDAORegistry";
import { ZDAORecord, ZNAAssociation } from "../generated/schema";
import { log } from "@graphprotocol/graph-ts";

export function handleDAOCreated(event: DAOCreated): void {
  const zDAO: ZDAORecord = new ZDAORecord(event.params.daoId.toString());
  zDAO.id = event.params.daoId.toString();
  zDAO.ensSpace = event.params.ensSpace;
  zDAO.gnosisSafe = event.params.gnosisSafe;
  zDAO.zNAs = [];
  zDAO.destroyed = false;
  zDAO.save();
}

export function handleDAODestroyed(event: DAODestroyed): void {
  const id = event.params.daoId.toString();
  const zDAO: ZDAORecord | null = ZDAORecord.load(id);
  if (zDAO) {
    zDAO.destroyed = true;
    zDAO.save();
  } else {
    log.error("Unable to load ZDAORecord with zDAOId {}", [
      id,
    ]);
  }
}

export function handleLinkAdded(event: LinkAdded): void {
  const zDAOId = event.params.daoId.toString();
  const zNA = event.params.zNA.toString();
  let zNAAssociation: ZNAAssociation | null = ZNAAssociation.load(zNA);
  if (zNAAssociation) {
    log.error("zNA {} was already added association with zDAO {}", [
      zNA,
      zDAOId,
    ]);
    return;
  }

  const zDAO: ZDAORecord | null = ZDAORecord.load(zDAOId);
  if (!zDAO) {
    log.error("Unable to load ZDAORecord with zDAOId {}", [
      zDAOId,
    ]);
    return;
  }
  if (zDAO.destroyed) {
    log.error("zDAO {} was already destroyed", [
      zDAOId,
    ]);
    return;
  }
  zDAO.zNAs.push(event.params.zNA.toString());
  zDAO.save();

  zNAAssociation = new ZNAAssociation(zNA);
  zNAAssociation.zDAORecord = zDAOId;
  zNAAssociation.save();
}

export function handleLinkRemoved(event: LinkRemoved): void {
  const zDAOId = event.params.daoId.toString();
  const zNA = event.params.zNA.toString();
  const zNAAssociation: ZNAAssociation | null = ZNAAssociation.load(zNA);
  if (!zNAAssociation) {
    log.error("Unable to load associated zNA {}", [
      zNA,
    ]);
    return;
  }
  
  const zDAO: ZDAORecord | null = ZDAORecord.load(zDAOId);
  if (!zDAO) {
    log.error("Unable to load ZDAORecord with zDAOId {}", [
      zDAOId,
    ]);
    return;
  }
  if (zDAO.destroyed) {
    log.error("zDAO {} was already destroyed", [
      zDAOId,
    ]);
    return;
  }

  zNAAssociation.zDAORecord = zDAOId;
  zNAAssociation.save();

  const index = zDAO.zNAs.indexOf(zNA);
  if (index >= 0) {
    zDAO.zNAs.splice(index, 1);
    zDAO.save();
  }
}
