// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IzDAOCore {
  struct DAO {
    string metadataUri;
    string[] zNAs;
    mapping(address => bool) admins;
  }

  event DAOCreated(string indexed daoId, string indexed metadataUri);
  event DAOzNAAdded(string indexed daoId, string indexed zNA);
  event DAOzNARemoved(string indexed daoId, string indexed zNA);
}
