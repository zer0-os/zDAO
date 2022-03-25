// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/IZDAOCore.sol";
import "./interfaces/IZNSHub.sol";

contract ZDAOCore is IZDAOCore, OwnableUpgradeable {
  using Counters for Counters.Counter;

  Counters.Counter private daoCounter;

  IZNSHub public znsHub;
  uint256[] private ensHashes; // to fetch data from snapshot
  mapping(uint256 => bool) public ensPresence;

  mapping(uint256 => DAO) private zDAOs;
  mapping(uint256 => uint256) public zNATozDAO;

  function initialize(address _znsHub) external initializer {
    __Ownable_init();

    znsHub = IZNSHub(_znsHub);
    daoCounter.increment(); // Starting from 1
  }

  function setZNSHub(address _znsHub) external onlyOwner {
    znsHub = IZNSHub(_znsHub);
  }

  function getEnsHashes() external view returns (uint256[] memory) {
    return ensHashes;
  }

  function getZDAO(uint256 daoId)
    external
    view
    onlyValidDAOId(daoId)
    returns (
      uint256,
      uint256,
      address,
      uint256[] memory
    )
  {
    DAO storage dao = zDAOs[daoId];
    return (dao.id, dao.ens, dao.gnosis, dao.zNAs);
  }

  // @feedback: Create ZDAO
  // Add new entry into the list of zDAO's assigns an id
  // Require gnosis safe address
  // Only callable by owner
  function addNewDAO(uint256 ens, address gnosis) external onlyOwner {
    require(!ensPresence[ens], "Already added");

    ensHashes.push(ens);
    ensPresence[ens] = true;
    uint256 current = daoCounter.current();

    DAO storage dao = zDAOs[current];
    dao.id = current;
    dao.ens = ens;
    dao.gnosis = gnosis;

    daoCounter.increment();

    emit DAOCreated(current, ens);
  }

  function addZNAAssociation(uint256 daoId, uint256 zNA)
    external
    onlyValidDAOId(daoId)
    onlyZNAOwner(zNA)
  {
    uint256 currentDAO = zNATozDAO[zNA];
    require(currentDAO != daoId, "Already added");

    if (currentDAO > 0) {
      // remove current DAO
      _removeZNAAssociation(currentDAO, zNA);
    }

    zNATozDAO[zNA] = daoId;
    zDAOs[daoId].zNAs.push(zNA);

    emit LinkAdded(daoId, zNA);
  }

  function removeZNAAssociation(uint256 daoId, uint256 zNA)
    external
    onlyValidDAOId(daoId)
    onlyZNAOwner(zNA)
  {
    uint256 currentDAO = zNATozDAO[zNA];
    require(currentDAO == daoId, "Not associated yet");

    _removeZNAAssociation(daoId, zNA);
  }

  function _removeZNAAssociation(uint256 daoId, uint256 zNA) internal {
    DAO storage dao = zDAOs[daoId];
    uint256 length = zDAOs[daoId].zNAs.length;

    for (uint256 i = 0; i < length; i++) {
      if (dao.zNAs[i] == zNA) {
        dao.zNAs[i] = dao.zNAs[length - 1];
        dao.zNAs.pop();
        zNATozDAO[zNA] = 0;

        emit LinkRemoved(daoId, zNA);
        break;
      }
    }
  }

  modifier onlyZNAOwner(uint256 zNA) {
    require(znsHub.ownerOf(zNA) == msg.sender, "Not zNA owner");
    _;
  }

  modifier onlyValidDAOId(uint256 daoId) {
    require(daoId > 0 && daoId < daoCounter.current(), "Invalid daoId");
    _;
  }
}
