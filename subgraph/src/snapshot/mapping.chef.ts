import { DAOCreated } from "../../generated/SnapshotZDAOChef/SnapshotZDAOChef";
import { SnapshotZDAO } from "../../generated/schema";
import { log } from "@graphprotocol/graph-ts";
import { PlatformType } from "../shared/config";
import { generateZDAOID, generateZDAORecordID } from "../shared/utils";

export function handleDAOCreated(event: DAOCreated): void {
  const platformType = PlatformType.Snapshot;
  const zDAOId = event.params._zDAOId.toI32();
  const zNA = event.params._zNA.toHexString();
  const createdBy = event.params._createdBy;
  const gnosisSafe = event.params._gnosisSafe;
  const ensSpace = event.params._ensSpace;

  log.info("handleDAOCreated, called {}, {}", [
    platformType.toString(),
    zDAOId.toString(),
  ]);

  const id = generateZDAOID(platformType, zDAOId);
  const zDAO: SnapshotZDAO = new SnapshotZDAO(id);
  zDAO.zDAORecord = generateZDAORecordID(platformType, zDAOId);
  zDAO.zDAOId = zDAOId;
  zDAO.createdBy = createdBy;
  zDAO.gnosisSafe = gnosisSafe;
  zDAO.ensSpace = ensSpace;
  zDAO.destroyed = false;

  zDAO.save();
}
