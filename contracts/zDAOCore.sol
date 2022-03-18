// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IzDAOCore.sol";

/*
zDAO
  - ID ~ Primary Key (increments for each new zDAO) (zDAO id)
  - snapshotId uint256
  - zNA uint256[]
  - ..... metadata and what not
*/


/* @feedback:

zNA association process:

Transaction 1: (By the owner of a zNA)*:
  - Make a request to associate zNA to zDAO
  - Store this request in this contract

Transaction 2: (By the Gnosis Safe)*:
  - Accepts the request to associate zNA to zDAO
  - Adds the zNA to the list + sets up any mappings

*for testing/debugging/initial development, these transactions can also
  be done by the contract owner (.owner())


-----

zNA disassociation:

Either the owner of zNA or the Gnosis Safe of a zDAO*:
  - Can make a transaction to remove the association from zNA <-> zDAO

*for testing/debugging/initial development, these transactions can also
  be done by the contract owner (.owner())

*/

//@feedback: These contracts need to be upgradeable using OZ upgrade pattern
contract zDAOCore is IzDAOCore, Ownable {
  // @feedback: use uint256 instead of strings
  // https://docs.ens.domains/contract-api-reference/name-processing
  // zNA's work a similar way
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

  // @feedback: Create ZDAO
  // Add new entry into the list of zDAO's assigns an id
  // Require gnosis safe address
  // Only callable by owner
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

  function setDAOMetadataUri(string calldata daoId, string calldata metadataUri)
    external
    onlyDAOAdmins(daoId)
  {
    zDAOs[daoId].metadataUri = metadataUri;
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
