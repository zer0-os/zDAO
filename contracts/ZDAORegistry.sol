// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/IZDAORegistry.sol";
import "./interfaces/IZNSHub.sol";

contract ZDAORegistry is IZDAORegistry, OwnableUpgradeable {
  using Counters for Counters.Counter;

  Counters.Counter public newDaoIndexTracker;

  IZNSHub public znsHub;

  mapping(uint256 => uint256) public ensTozDAO;
  mapping(uint256 => uint256) private zNATozDAOId;
  ZDAORecord[] public zDAORecords;

  modifier onlyZNAOwner(uint256 zNA) {
    require(znsHub.ownerOf(zNA) == msg.sender, "Not zNA owner");
    _;
  }

  modifier onlyValidZDAO(uint256 daoId) {
    require(daoId > 0 && daoId < newDaoIndexTracker.current(), "Invalid daoId");
    _;
  }

  function initialize(address _znsHub) external initializer {
    __Ownable_init();

    znsHub = IZNSHub(_znsHub);
    zDAORecords.push(
      ZDAORecord({id: 0, ensId: 0, gnosisSafe: address(0), associatedzNAs: new uint256[](0)})
    );

    newDaoIndexTracker.increment(); // Starting from 1
  }

  function setZNSHub(address _znsHub) external onlyOwner {
    znsHub = IZNSHub(_znsHub);
  }

  function addNewDAO(uint256 ensId, address gnosisSafe) external onlyOwner {
    uint256 newZDAOId = newDaoIndexTracker.current();

    zDAORecords[newZDAOId] = ZDAORecord({
      id: newZDAOId,
      ensId: ensId,
      gnosisSafe: gnosisSafe,
      associatedzNAs: new uint256[](0)
    });

    newDaoIndexTracker.increment();

    emit DAOCreated(newZDAOId, ensId, gnosisSafe);
  }

  function addZNAAssociation(uint256 daoId, uint256 zNA)
    external
    onlyValidZDAO(daoId)
    onlyZNAOwner(zNA)
  {
    uint256 currentDAOAssociation = zNATozDAOId[zNA];
    require(currentDAOAssociation != daoId, "zNA already linked to DAO");

    // If an association already exists, remove it
    if (currentDAOAssociation != 0) {
      _removeZNAAssociation(currentDAOAssociation, zNA);
    }

    zNATozDAOId[zNA] = daoId;
    zDAORecords[daoId].associatedzNAs.push(zNA);

    emit LinkAdded(daoId, zNA);
  }

  function removeZNAAssociation(uint256 daoId, uint256 zNA)
    external
    onlyValidZDAO(daoId)
    onlyZNAOwner(zNA)
  {
    uint256 currentDAOAssociation = zNATozDAOId[zNA];
    require(currentDAOAssociation == daoId, "zNA not associated");

    _removeZNAAssociation(daoId, zNA);
  }

  function numberOfzDAOs() external view returns (uint256) {
    return newDaoIndexTracker.current() - 1;
  }

  function getzDAOById(uint256 daoId) external view returns (ZDAORecord memory) {
    return zDAORecords[daoId];
  }

  function listzDAOs(uint256 startIndex, uint256 endIndex)
    external
    view
    returns (ZDAORecord[] memory)
  {
    uint256 numDaos = newDaoIndexTracker.current() - 1;
    if (numDaos == 0) {
      return new ZDAORecord[](0);
    }
    require(startIndex < endIndex, "start index > end");
    require(startIndex < numDaos - 1, "start index > length");
    require(endIndex <= numDaos, "end index > length");

    uint256 numRecords = endIndex - startIndex;
    ZDAORecord[] memory records = new ZDAORecord[](numRecords);

    for (uint256 i = 0; i < numRecords; ++i) {
      records[i] = zDAORecords[startIndex + i];
    }

    return records;
  }

  function getzDaoByZNA(uint256 zNA) external view returns (ZDAORecord memory) {
    uint256 daoId = zNATozDAOId[zNA];
    require(daoId != 0 && daoId < newDaoIndexTracker.current(), "No zDAO associated with zNA");
    return zDAORecords[daoId];
  }

  function doeszDAOExistForzNA(uint256 zNA) external view returns (bool) {
    return zNATozDAOId[zNA] != 0;
  }

  function _removeZNAAssociation(uint256 daoId, uint256 zNA) internal {
    ZDAORecord storage dao = zDAORecords[daoId];
    uint256 length = zDAORecords[daoId].associatedzNAs.length;

    for (uint256 i = 0; i < length; i++) {
      if (dao.associatedzNAs[i] == zNA) {
        dao.associatedzNAs[i] = dao.associatedzNAs[length - 1];
        dao.associatedzNAs.pop();
        zNATozDAOId[zNA] = 0;

        emit LinkRemoved(daoId, zNA);
        break;
      }
    }
  }
}
