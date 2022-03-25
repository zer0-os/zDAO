// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IZDAOCore {
  struct DAO {
    uint256 id;
    uint256 ens;
    address gnosis;
    uint256[] zNAs;
  }

  event DAOCreated(uint256 indexed daoId, uint256 ens);
  event LinkAdded(uint256 indexed daoId, uint256 indexed zNA);
  event LinkRemoved(uint256 indexed daoId, uint256 indexed zNA);
}
