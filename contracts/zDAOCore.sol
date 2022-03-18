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
    string calldata daoId,
    string calldata metadataUri,
    address[] calldata admins
  ) external onlyManagers {
    if (!zDAOIDPresence[daoId]) {
      zDAOIds.push(daoId);
      zDAOIDPresence[daoId] = true;

      DAO storage dao = zDAOs[daoId];
      dao.metadataUri = metadataUri;
      for (uint256 i = 0; i < admins.length; i++) {
        dao.admins[admins[i]] = true;
      }

      emit DAOCreated(daoId, metadataUri);
    }
  }

  function setDAOAdmin(
    string calldata daoId,
    address admin,
    bool flag
  ) external onlyDAOAdmins(daoId) {
    zDAOs[daoId].admins[admin] = flag;
  }

  function addZNAAssociation(string calldata daoId, string calldata zNA)
    external
    onlyDAOAdmins(daoId)
  {
    string memory currentDAO = zNATozDAO[zNA];
    require(!strcmp(currentDAO, daoId), "Already added");

    if (!strcmp(currentDAO, "")) {
      // remove current DAO
      _removeZNAAssociation(currentDAO, zNA);
    }

    zNATozDAO[zNA] = daoId;
    zDAOs[daoId].zNAs.push(zNA);

    emit DAOzNAAdded(daoId, zNA);
  }

  function removeZNAAssociation(string calldata daoId, string calldata zNA)
    external
    onlyDAOAdmins(daoId)
  {
    string memory currentDAO = zNATozDAO[zNA];
    require(strcmp(currentDAO, daoId), "Not associated yet");

    _removeZNAAssociation(daoId, zNA);
  }

  function _removeZNAAssociation(string memory daoId, string memory zNA) internal {
    DAO storage dao = zDAOs[daoId];
    uint256 length = zDAOs[daoId].zNAs.length;
    for (uint256 i = 0; i < length; i++) {
      if (strcmp(dao.zNAs[i], zNA)) {
        dao.zNAs[i] = dao.zNAs[length - 1];
        dao.zNAs.pop();
        zNATozDAO[zNA] = "";

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

  modifier onlyDAOAdmins(string calldata daoId) {
    require(zDAOIDPresence[daoId], "DAO ID invalid");
    DAO storage dao = zDAOs[daoId];
    require(dao.admins[msg.sender], "Only DAO admins can update association");
    _;
  }

  modifier onlyManagers {
    require(msg.sender == owner() || managers[msg.sender], "Not allowed");
    _;
  }
}
