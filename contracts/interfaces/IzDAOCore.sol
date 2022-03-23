// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IZDAOCore {
  struct DAO {
    uint256 id;
    uint256 ens; // ENS record for now
    address gnosis;
    uint256[] zNAs;
    // @feedback: Include a gnosis safe address as a member
    // @feedback: Drop an admin concept of a zDAO
    // @feedback: Instead require certain methods to be called by the zDAO gnosis safe
  }

  //@feedback: Make sure events happen for any transaction that causes state change
  // ie: LinkRequested, LinkAccepted, LinkRemoved, DAOCreated
  event DAOCreated(uint256 indexed daoId, uint256 ens);
  event LinkAdded(uint256 indexed daoId, uint256 indexed zNA);
  event LinkRemoved(uint256 indexed daoId, uint256 indexed zNA);
}
