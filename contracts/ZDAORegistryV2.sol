// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/IZDAORegistryV2.sol";
import "./interfaces/IZNSHub.sol";

contract ZDAORegistryV2 is IZDAORegistryV2, OwnableUpgradeable {
  IZNSHub public znsHub;

  mapping(uint256 => uint256) private ensTozDAO;
  mapping(uint256 => uint256) private zNATozDAOId;

  // The zdao at index 0 is a null zDAO
  // We use a mapping instead of an array for upgradeability
  mapping(uint256 => ZDAORecord) public zDAORecords;

  // More of a 'new zdao index' tracker
  uint256 private numZDAOs;

  modifier onlyzNAOwner(uint256 zNA) {
    require(znsHub.ownerOf(zNA) == msg.sender, "Not zNA owner");
    _;
  }

  modifier onlyValidzDAO(uint256 zDAOId) {
    require(zDAOId > 0 && zDAOId < numZDAOs && !zDAORecords[zDAOId].destroyed, "Invalid zDAO");
    _;
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function initialize(address zNSHub_) external initializer {
    __Ownable_init();

    znsHub = IZNSHub(zNSHub_);
    zDAORecords[0] = ZDAORecord({
      id: 0,
      ensSpace: "",
      gnosisSafe: address(0),
      associatedzNAs: new uint256[](0),
      destroyed: false,
      token: address(0)
    });

    numZDAOs = 1;
  }

  /**
   * Add new DAO with ENS name and Gnosis Safe address
   * @param ensSpace ENS name
   * @param gnosisSafe Address to Gnosis Safe
   */
  function addNewDAO(string calldata ensSpace, address gnosisSafe) external onlyOwner {
    _addNewDAO(ensSpace, gnosisSafe, address(0));
  }

  /**
   * Add new DAO with ENS name, Gnosis Safe address and token
   * @param ensSpace ENS name
   * @param gnosisSafe Address to Gnosis Safe
   * @param token Address to default DAO token
   */
  function addNewDAOWithToken(string calldata ensSpace, address gnosisSafe, address token) external onlyOwner {
    _addNewDAO(ensSpace, gnosisSafe, token);
  }

  /**
   * Associate DAO with zNA
   * @param zDAOId zDAOId, starting from 1
   * @param zNA zNA domain id
   */
  function addZNAAssociation(uint256 zDAOId, uint256 zNA)
    external
    onlyValidzDAO(zDAOId)
    onlyzNAOwner(zNA)
  {
    _associatezNA(zDAOId, zNA);
  }

  /**
   * Disassociate DAO from zNA
   * @param zDAOId zDAOId, starting from 1
   * @param zNA zNA domain id
   */
  function removeZNAAssociation(uint256 zDAOId, uint256 zNA)
    external
    onlyValidzDAO(zDAOId)
    onlyzNAOwner(zNA)
  {
    require(zNATozDAOId[zNA] == zDAOId, "zNA not associated");

    _disassociatezNA(zDAOId, zNA);
  }

  /* -------------------------------------------------------------------------- */
  /*                               Admin Functions                              */
  /* -------------------------------------------------------------------------- */

  /**
   * Set zNSHub address
   * @dev Callable by only owner
   * @param zNSHub_ Address to zNSHub
   */
  function adminSetZNSHub(address zNSHub_) external onlyOwner {
    znsHub = IZNSHub(zNSHub_);
    emit ZNSHubChanged(zNSHub_);
  }

  /**
   * Remove zDAO
   * @dev Callable by only owner
   * @param zDAOId zDAOId, starting from 1
   */
  function adminRemoveDAO(uint256 zDAOId) external onlyValidzDAO(zDAOId) onlyOwner {
    zDAORecords[zDAOId].destroyed = true;
    uint256 ensId = _ensId(zDAORecords[zDAOId].ensSpace);
    ensTozDAO[ensId] = 0;

    emit DAODestroyed(zDAOId);
  }

  /**
   * Add association between zDAO and zNA
   * @dev Callable by only owner
   * @param zDAOId zDAOId, starting from 1
   * @param zNA zNA domain id
   */
  function adminAssociatezNA(uint256 zDAOId, uint256 zNA) external onlyOwner onlyValidzDAO(zDAOId) {
    _associatezNA(zDAOId, zNA);
  }

  /**
   * Remove association between zDAO and zNA
   * @dev Callable by only owner
   * @param zDAOId zDAOId, starting from 1
   * @param zNA zNA domain id
   */
  function adminDisassociatezNA(uint256 zDAOId, uint256 zNA)
    external
    onlyOwner
    onlyValidzDAO(zDAOId)
  {
    require(zNATozDAOId[zNA] == zDAOId, "zNA not associated");

    _disassociatezNA(zDAOId, zNA);
  }

  /**
   * Modify ENS name and Gnosis Safe address in zDAO
   * @dev Callable by only owner
   * @param zDAOId zDAOId, starting from 1
   * @param ensSpace ENS name
   * @param gnosisSafe Address to Gnosis Safe
   */
  function adminModifyzDAO(
    uint256 zDAOId,
    string calldata ensSpace,
    address gnosisSafe
  ) external onlyOwner onlyValidzDAO(zDAOId) {
    ZDAORecord storage zDAO = zDAORecords[zDAOId];

    uint256 newEnsId = _ensId(ensSpace);
    require(ensTozDAO[newEnsId] == 0, "ENS already has zDAO");
    uint256 existingEnsId = _ensId(zDAO.ensSpace);

    if (newEnsId != existingEnsId) {
      ensTozDAO[existingEnsId] = 0;
      ensTozDAO[newEnsId] = zDAOId;
    }

    zDAO.ensSpace = ensSpace;
    zDAO.gnosisSafe = gnosisSafe;

    emit DAOModified(zDAOId, ensSpace, gnosisSafe);
  }

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  // The number of actual zDAO's (excludes '0' which is null)
  function numberOfzDAOs() external view returns (uint256) {
    return numZDAOs - 1;
  }

  function getzDAOById(uint256 zDAOId) external view returns (ZDAORecord memory) {
    return zDAORecords[zDAOId];
  }

  function listzDAOs(uint256 startIndex, uint256 endIndex)
    external
    view
    returns (ZDAORecord[] memory)
  {
    uint256 numDaos = numZDAOs;
    require(startIndex != 0, "start index = 0, use 1");
    require(startIndex <= endIndex, "start index > end");
    require(startIndex < numDaos, "start index > length");
    require(endIndex < numDaos, "end index > length");

    if (numDaos == 1) {
      return new ZDAORecord[](0);
    }

    uint256 numRecords = endIndex - startIndex + 1;
    ZDAORecord[] memory records = new ZDAORecord[](numRecords);

    for (uint256 i = 0; i < numRecords; ++i) {
      records[i] = zDAORecords[startIndex + i];
    }

    return records;
  }

  function getzDAOByzNA(uint256 zNA) external view returns (ZDAORecord memory) {
    uint256 zDAOId = zNATozDAOId[zNA];
    require(
      zDAOId != 0 && zDAOId < numZDAOs && !zDAORecords[zDAOId].destroyed,
      "No zDAO associated with zNA"
    );
    return zDAORecords[zDAOId];
  }

  function getzDAOByENS(string calldata ensSpace) external view returns (ZDAORecord memory) {
    uint256 ensHash = _ensId(ensSpace);
    uint256 zDAOId = ensTozDAO[ensHash];
    require(zDAOId != 0, "No zDAO at ens space");
    require(!zDAORecords[zDAOId].destroyed, "zDAO destroyed");

    return zDAORecords[zDAOId];
  }

  function doeszDAOExistForzNA(uint256 zNA) external view returns (bool) {
    return zNATozDAOId[zNA] != 0;
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal Functions                             */
  /* -------------------------------------------------------------------------- */

  function _addNewDAO(string calldata ensSpace, address gnosisSafe, address token) internal {
    uint256 ensId = _ensId(ensSpace);
    require(ensTozDAO[ensId] == 0, "ENS already has zDAO");

    zDAORecords[numZDAOs] = ZDAORecord({
      id: numZDAOs,
      ensSpace: ensSpace,
      gnosisSafe: gnosisSafe,
      associatedzNAs: new uint256[](0),
      destroyed: false,
      token: token
    });

    ensTozDAO[ensId] = numZDAOs;

    emit DAOCreatedWithToken(numZDAOs, ensSpace, gnosisSafe, token);

    numZDAOs += 1;
  }

  function _associatezNA(uint256 zDAOId, uint256 zNA) internal {
    uint256 currentDAOAssociation = zNATozDAOId[zNA];
    require(currentDAOAssociation != zDAOId, "zNA already linked to DAO");

    // If an association already exists, remove it
    if (currentDAOAssociation != 0) {
      _disassociatezNA(currentDAOAssociation, zNA);
    }

    zNATozDAOId[zNA] = zDAOId;
    zDAORecords[zDAOId].associatedzNAs.push(zNA);

    emit LinkAdded(zDAOId, zNA);
  }

  function _disassociatezNA(uint256 zDAOId, uint256 zNA) internal {
    ZDAORecord storage dao = zDAORecords[zDAOId];
    uint256 length = zDAORecords[zDAOId].associatedzNAs.length;

    for (uint256 i = 0; i < length; i++) {
      if (dao.associatedzNAs[i] == zNA) {
        dao.associatedzNAs[i] = dao.associatedzNAs[length - 1];
        dao.associatedzNAs.pop();
        zNATozDAOId[zNA] = 0;

        emit LinkRemoved(zDAOId, zNA);
        break;
      }
    }
  }

  function _ensId(string memory ensSpace) private pure returns (uint256) {
    uint256 ensHash = uint256(keccak256(abi.encodePacked(ensSpace)));
    return ensHash;
  }
}
