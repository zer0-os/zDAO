import {
  DAOCreated, DAOCreatedWithToken, DAODestroyed, LinkAdded, LinkRemoved
} from "../generated/ZDAORegistry/ZDAORegistry";
import { ZDAORecord, ZNAAssociation } from "../generated/schema";
import { Bytes, log, store } from "@graphprotocol/graph-ts";

function generateZDAORecordID(platformType: number, zDAOId: number): string {
  const id = `${platformType.toString()}-${zDAOId.toString()}`;
  return id;
}

export function handleDAOCreated(event: DAOCreated): void {
  const platformType = 0; // 0: Snapshot
  const zDAOId = event.params.zDAOId.toI32();
  const id = generateZDAORecordID(platformType, zDAOId);

  log.info("handleDAOCreated, called {}", [id]);

  const zDAO: ZDAORecord = new ZDAORecord(id);
  zDAO.id = id;
  zDAO.platformType = platformType;
  zDAO.zDAOId = zDAOId;
  zDAO.name = event.params.ensSpace;
  zDAO.gnosisSafe = event.params.gnosisSafe;
  zDAO.token = Bytes.empty();
  zDAO.createdBy = Bytes.empty();
  zDAO.destroyed = false;
  zDAO.save();
}

export function handleDAOCreatedWithToken(event: DAOCreatedWithToken): void {
  const platformType = 0; // 0: Snapshot
  const zDAOId = event.params.zDAOId.toI32();
  const id = generateZDAORecordID(platformType, zDAOId);

  log.info("handleDAOCreated, called {}", [id]);

  const zDAO: ZDAORecord = new ZDAORecord(id);
  zDAO.id = id;
  zDAO.platformType = platformType;
  zDAO.zDAOId = zDAOId;
  zDAO.name = event.params.ensSpace;
  zDAO.gnosisSafe = event.params.gnosisSafe;
  zDAO.token = event.params.token;
  zDAO.createdBy = Bytes.empty();
  zDAO.destroyed = false;
  zDAO.save();
}

export function handleDAOModified(event: DAOCreated): void {
  const platformType = 0; // 0: Snapshot
  const zDAOId = event.params.zDAOId.toI32();
  const id = generateZDAORecordID(platformType, zDAOId);

  log.info("handleDAOModified, called {}", [id]);

  let zDAO: ZDAORecord | null = ZDAORecord.load(id);
  if (zDAO) {
    zDAO.name = event.params.ensSpace;
    zDAO.gnosisSafe = event.params.gnosisSafe;
    zDAO.save();
  } else {
    log.error("handleDAOModified, Unable to load ZDAORecord with zDAOId {}, {}", [
      id,
      event.block.number.toString()
    ]);
  }
}

export function handleDAODestroyed(event: DAODestroyed): void {
  const platformType = 0; // 0: Snapshot
  const zDAOId = event.params.zDAOId.toI32();
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
  const zDAOId = event.params.zDAOId.toI32();
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
  const zDAOId = event.params.zDAOId.toI32();
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
