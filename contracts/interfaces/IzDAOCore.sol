// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IzDAOCore {
  struct DAO {
    // @feedback: Drop Metadatauri, it's not being used right now
    string metadataUri;
    string[] zNAs;
    // @feedback: Include a gnosis safe address as a member
    // @feedback: Drop an admin concept of a zDAO
    // @feedback: Instead require certain methods to be called by the zDAO gnosis safe
    mapping(address => bool) admins;
  }

  //@feedback: Make sure events happen for any transaction that causes state change
  // ie: LinkRequested, LinkAccepted, LinkRemoved, DAOCreated
  event DAOCreated(string indexed daoId, string indexed metadataUri);
  event DAOzNAAdded(string indexed daoId, string indexed zNA);
  event DAOzNARemoved(string indexed daoId, string indexed zNA);
}
