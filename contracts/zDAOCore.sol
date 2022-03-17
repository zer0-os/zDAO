// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

contract zDAOCore is Ownable {
  string[] public zDAOIds;
  mapping(string => bool) zDAOIDPresence;

  struct DAO {
    string[] zNAs;
    mapping(address => bool) admins;
  }

  mapping(string => DAO) zDAOs;
  mapping(string => string) zNATozDAO;

  /// @dev Allowed core managers
  mapping(address => bool) private managers;

  function addNewDAO(string calldata newDAO, address[] calldata admins) external onlyManagers {
    if (!zDAOIDPresence[newDAO]) {
      zDAOIds.push(newDAO);
      zDAOIDPresence[newDAO] = true;
      for (uint256 i = 0; i < admins.length; i++) {
        zDAOs[newDAO].admins[admins[i]] = true;
      }
    }
  }

  function addZNAAssociation(string memory daoId, string memory zNA) external {
    require(zDAOIDPresence[daoId], "DAO ID invalid");
    require(zDAOs[daoId].admins[msg.sender], "Only DAO admins can add new association");
    string memory currentDAO = zNATozDAO[zNA];
    require(!strcmp(currentDAO, daoId), "Already added");

    if (!strcmp(currentDAO, "")) {
      // remove current DAO
      _removeZNAAssociation(currentDAO, zNA);
    }

    zNATozDAO[zNA] = daoId;
    zDAOs[daoId].zNAs.push(zNA);
  }

  function removeZNAAssociation(string memory daoId, string memory zNA) external {
    require(zDAOIDPresence[daoId], "DAO ID invalid");
    require(zDAOs[daoId].admins[msg.sender], "Only DAO admins can add remove association");

    _removeZNAAssociation(daoId, zNA);
  }

  function _removeZNAAssociation(string memory daoId, string memory zNA) internal {
    uint256 length = zDAOs[daoId].zNAs.length;
    for (uint256 i = 0; i < length; i++) {
      if (strcmp(zDAOs[daoId].zNAs[i], zNA)) {
        zDAOs[daoId].zNAs[i] = zDAOs[daoId].zNAs[length - 1];
        zDAOs[daoId].zNAs.pop();
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
