// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IzDAOCore.sol";

contract zDAOCore is IzDAOCore, Ownable {
  string[] private zDAOIds;
  mapping(string => bool) public zDAOIDPresence;

  mapping(string => DAO) private zDAOs;
  mapping(string => string) public zNATozDAO;

  /// @dev Allowed core managers
  mapping(address => bool) private managers;

  function getDAOIds() external view returns (string[] memory) {
    return zDAOIds;
  }

  function getDAOMetadataUri(string calldata daoId)
    external
    view
    returns (string memory metadataUri)
  {
    return zDAOs[daoId].metadataUri;
  }

  function getDAOZNAs(string calldata daoId) external view returns (string[] memory) {
    return zDAOs[daoId].zNAs;
  }

  function addNewDAO(
    string calldata _daoId,
    string calldata _metadataUri,
    address[] calldata admins
  ) external onlyManagers {
    if (!zDAOIDPresence[_daoId]) {
      zDAOIds.push(_daoId);
      zDAOIDPresence[_daoId] = true;

      DAO storage dao = zDAOs[_daoId];
      dao.metadataUri = _metadataUri;
      for (uint256 i = 0; i < admins.length; i++) {
        dao.admins[admins[i]] = true;
      }

      emit DAOCreated(_daoId, _metadataUri);
    }
  }

  function addZNAAssociation(string memory daoId, string memory zNA) external {
    require(zDAOIDPresence[daoId], "DAO ID invalid");
    DAO storage dao = zDAOs[daoId];
    require(dao.admins[msg.sender], "Only DAO admins can add new association");
    string memory currentDAO = zNATozDAO[zNA];
    require(!strcmp(currentDAO, daoId), "Already added");

    if (!strcmp(currentDAO, "")) {
      // remove current DAO
      _removeZNAAssociation(currentDAO, zNA);
    }

    zNATozDAO[zNA] = daoId;
    dao.zNAs.push(zNA);

    emit DAOzNAAdded(daoId, zNA);
  }

  function removeZNAAssociation(string memory daoId, string memory zNA) external {
    require(zDAOIDPresence[daoId], "DAO ID invalid");
    require(zDAOs[daoId].admins[msg.sender], "Only DAO admins can add remove association");

    _removeZNAAssociation(daoId, zNA);
  }

  function _removeZNAAssociation(string memory daoId, string memory zNA) internal {
    DAO storage dao = zDAOs[daoId];
    uint256 length = zDAOs[daoId].zNAs.length;
    for (uint256 i = 0; i < length; i++) {
      if (strcmp(dao.zNAs[i], zNA)) {
        dao.zNAs[i] = dao.zNAs[length - 1];
        dao.zNAs.pop();

        emit DAOzNARemoved(daoId, zNA);
        break;
      }
    }
  }

  function setManager(address manager, bool allowed) external onlyOwner {
    managers[manager] = allowed;
  }

  function strcmp(string memory a, string memory b) internal pure returns (bool) {
    return keccak256(abi.encode(a)) == keccak256(abi.encode(b));
  }

  modifier onlyManagers {
    require(msg.sender == owner() || managers[msg.sender], "Not allowed");
    _;
  }
}
