// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {console} from "hardhat/console.sol";
import {ZeroUpgradeable} from "./abstracts/ZeroUpgradeable.sol";
import {IZDAOFactory} from "./interfaces/IZDAOFactory.sol";
import {IZDAORegistry} from "./interfaces/IZDAORegistry.sol";
import {IZNSHub} from "./interfaces/IZNSHub.sol";

contract ZDAORegistry is ZeroUpgradeable, IZDAORegistry {
  IZNSHub public znsHub;

  // zNA    => zDAOId
  mapping(uint256 => uint256) public zNATozDAOId;
  // zDAOId => zDAORecord
  mapping(uint256 => ZDAORecord) public zDAORecords;
  // PlatformType => IZDAOFactory
  mapping(uint256 => IZDAOFactory) public zDAOFactories;

  uint256 public lastZDAOId;

  /* -------------------------------------------------------------------------- */
  /*                                  Modifiers                                 */
  /* -------------------------------------------------------------------------- */

  modifier onlyZNAOwner(uint256 _zNA) {
    require(znsHub.ownerOf(_zNA) == msg.sender, "Not a zNA owner");
    _;
  }

  modifier onlyValidZDAO(uint256 _zDAOId) {
    require(
      _zDAOId > 0 && _zDAOId <= lastZDAOId && !_isZDAODestroyed(_zDAOId),
      "Invalid zDAO"
    );
    _;
  }

  modifier onlyDAOOwner(uint256 _zDAOId) {
    require(
      msg.sender == zDAORecords[_zDAOId].zDAOOwnedBy,
      "Invalid zDAO Owner"
    );
    _;
  }

  /* -------------------------------------------------------------------------- */
  /*                                 Initializer                                */
  /* -------------------------------------------------------------------------- */

  function __ZDAORegistry_init(IZNSHub _znsHub) public initializer {
    ZeroUpgradeable.__ZeroUpgradeable_init();

    znsHub = _znsHub;
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function setZNSHub(address _znsHub) external onlyOwner {
    znsHub = IZNSHub(_znsHub);
  }

  function addZDAOFactory(
    IZDAORegistry.PlatformType _platformType,
    IZDAOFactory _factory
  ) external onlyOwner {
    uint256 platformType = uint256(_platformType);
    require(
      address(zDAOFactories[platformType]) == address(0),
      "Already has factory address"
    );
    zDAOFactories[platformType] = _factory;
  }

  /**
   * @notice Add new zDAO associating with given zNA.
   *     Create new RootZDAO contract and associate new zDAO with given zNA.
   *     Once create new zDAO, it should be synchronized to Polygon.
   *     Users can create proposal and cast a vote after zDAO synchronization.
   * @dev Only zNA owner can create zDAO
   * @param _platformType PlatformType enum value
   * @param _zNA zNA unique Id
   * @param _gnosisSafe Gnosis Safe address per zDAO
   * @param _options Abi encoded the structure of zDAO information
   */
  function addNewZDAO(
    uint256 _platformType,
    uint256 _zNA,
    address _gnosisSafe,
    bytes calldata _options
  ) external override onlyZNAOwner(_zNA) {
    uint256 zDAOId = zNATozDAOId[_zNA];
    require(zDAOId == 0, "Already added DAO with same zNA");

    IZDAOFactory factory = zDAOFactories[_platformType];
    assert(address(factory) != address(0));

    lastZDAOId++;
    address zDAO = factory.addNewZDAO(lastZDAOId, _zNA, _gnosisSafe, _options);

    zDAORecords[lastZDAOId] = ZDAORecord({
      platformType: _platformType,
      id: lastZDAOId,
      zDAO: zDAO,
      zDAOOwnedBy: msg.sender,
      gnosisSafe: _gnosisSafe,
      destroyed: false,
      associatedzNAs: new uint256[](0)
    });

    emit DAOCreated(
      _platformType,
      lastZDAOId,
      _gnosisSafe,
      msg.sender,
      address(zDAO)
    );

    // Associate zDAO with zNA
    _associatezNA(lastZDAOId, _zNA);
  }

  /**
   * @notice Add association with zNA
   * @dev Callable by zDAO owner and for valid zDAO
   * @param _zDAOId zDAO unique id
   * @param _zNA zNA id required to associate
   */
  function addZNAAssociation(uint256 _zDAOId, uint256 _zNA)
    external
    override
    onlyValidZDAO(_zDAOId)
    onlyZNAOwner(_zNA)
  {
    _associatezNA(_zDAOId, _zNA);
  }

  /**
   * @notice Remove association from given zDAO
   * @dev Callable by zDAO owner and for valid zDAO
   * @param _zDAOId zDAO unique id
   * @param _zNA zNA id required to remove
   */
  function removeZNAAssociation(uint256 _zDAOId, uint256 _zNA)
    external
    override
    onlyValidZDAO(_zDAOId)
    onlyZNAOwner(_zNA)
  {
    require(_zDAOId > 0 && _zDAOId <= lastZDAOId, "Invalid zDAO");
    require(zNATozDAOId[_zNA] == _zDAOId, "zNA not associated");

    _disassociatezNA(_zDAOId, _zNA);
  }

  /**
   * @notice Remove zDAO by zDAOId.
   *     Removed state should be synchronized to Polygon, so that stop
   *     user voting
   * @dev Only owner can remove zDAO, and only for valid zDAO
   * @param _zDAOId zDAO unique id
   */
  function adminRemoveZDAO(uint256 _zDAOId)
    external
    onlyValidZDAO(_zDAOId)
    onlyOwner
  {
    ZDAORecord storage zDAORecord = zDAORecords[_zDAOId];

    IZDAOFactory factory = zDAOFactories[zDAORecord.platformType];
    assert(address(factory) != address(0));

    zDAORecord.destroyed = true;
    factory.removeZDAO(_zDAOId);

    emit DAODestroyed(_zDAOId);
  }

  function adminAssociateZNA(uint256 _zDAOId, uint256 _zNA)
    external
    onlyValidZDAO(_zDAOId)
    onlyOwner
  {
    _associatezNA(_zDAOId, _zNA);
  }

  function adminDisassociateZNA(uint256 _zDAOId, uint256 _zNA)
    external
    onlyValidZDAO(_zDAOId)
    onlyOwner
  {
    require(_zDAOId > 0 && _zDAOId <= lastZDAOId, "Invalid zDAO");
    require(zNATozDAOId[_zNA] == _zDAOId, "zNA not associated");

    _disassociatezNA(_zDAOId, _zNA);
  }

  function adminModifyZDAO(
    uint256 _zDAOId,
    address _gnosisSafe,
    bytes calldata _options
  ) external onlyValidZDAO(_zDAOId) onlyOwner {
    ZDAORecord storage zDAORecord = zDAORecords[_zDAOId];

    IZDAOFactory factory = zDAOFactories[zDAORecord.platformType];
    assert(address(factory) != address(0));

    zDAORecord.gnosisSafe = _gnosisSafe;
    factory.modifyZDAO(_zDAOId, _gnosisSafe, _options);

    emit DAOModified(_zDAOId, _gnosisSafe);
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal Functions                             */
  /* -------------------------------------------------------------------------- */

  function _isZDAODestroyed(uint256 _index) internal view returns (bool) {
    return zDAORecords[_index].destroyed;
  }

  function _associatezNA(uint256 _zDAOId, uint256 _zNA) internal {
    uint256 currentDAOAssociation = zNATozDAOId[_zNA];
    require(currentDAOAssociation != _zDAOId, "zNA already linked to DAO");

    // If an association already exists, remove it
    if (currentDAOAssociation != 0) {
      _disassociatezNA(currentDAOAssociation, _zNA);
    }

    zNATozDAOId[_zNA] = _zDAOId;
    zDAORecords[_zDAOId].associatedzNAs.push(_zNA);

    emit LinkAdded(_zDAOId, _zNA);
  }

  function _disassociatezNA(uint256 _zDAOId, uint256 _zNA) internal {
    ZDAORecord storage dao = zDAORecords[_zDAOId];
    uint256 length = zDAORecords[_zDAOId].associatedzNAs.length;

    for (uint256 i = 0; i < length; i++) {
      if (dao.associatedzNAs[i] == _zNA) {
        dao.associatedzNAs[i] = dao.associatedzNAs[length - 1];
        dao.associatedzNAs.pop();
        zNATozDAOId[_zNA] = 0;

        emit LinkRemoved(_zDAOId, _zNA);
        break;
      }
    }
  }

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function numberOfzDAOs() external view override returns (uint256) {
    return lastZDAOId;
  }

  function listZDAOs(uint256 _startIndex, uint256 _count)
    external
    view
    override
    returns (ZDAORecord[] memory records)
  {
    uint256 numRecords = _count;
    if (numRecords > (lastZDAOId - _startIndex)) {
      numRecords = lastZDAOId - _startIndex;
    }

    records = new ZDAORecord[](numRecords);

    for (uint256 i = 0; i < numRecords; ++i) {
      records[i] = zDAORecords[_startIndex + i + 1];
    }

    return records;
  }

  function getZDAOByZNA(uint256 _zNA)
    external
    view
    override
    returns (ZDAORecord memory)
  {
    uint256 zDAOId = zNATozDAOId[_zNA];
    require(zDAOId > 0 && zDAOId <= lastZDAOId, "No zDAO associated with zNA");
    return zDAORecords[zDAOId];
  }

  function getZDAOZNAs(uint256 _zDAOId)
    external
    view
    returns (uint256[] memory)
  {
    return zDAORecords[_zDAOId].associatedzNAs;
  }

  function doesZNAExistForZNA(uint256 _zNA)
    external
    view
    override
    returns (bool)
  {
    return zNATozDAOId[_zNA] != 0;
  }
}
