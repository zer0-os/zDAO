// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {ZeroUpgradeable} from "./abstracts/ZeroUpgradeable.sol";
import {IResourceRegistry} from "./interfaces/IResourceRegistry.sol";
import {IZDAOFactory} from "./interfaces/IZDAOFactory.sol";
import {IZDAORegistry} from "./interfaces/IZDAORegistry.sol";
import {IZNAResolver} from "./interfaces/IZNAResolver.sol";
import {IZNSHub} from "./interfaces/IZNSHub.sol";

contract ZDAORegistry is ZeroUpgradeable, IZDAORegistry, IResourceRegistry {
  IZNSHub public znsHub;

  IZNAResolver public zNAResolver;

  // zDAOId => zDAORecord
  mapping(uint256 => ZDAORecord) public zDAORecords;
  // zDAO name => bool
  mapping(uint256 => bool) public zDAONames;
  // PlatformType => IZDAOFactory
  mapping(uint256 => IZDAOFactory) public override zDAOFactories;

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

  /* -------------------------------------------------------------------------- */
  /*                                 Initializer                                */
  /* -------------------------------------------------------------------------- */

  function __ZDAORegistry_init(IZNSHub _znsHub, IZNAResolver _zNAResolver)
    public
    initializer
  {
    ZeroUpgradeable.__ZeroUpgradeable_init();

    znsHub = _znsHub;
    zNAResolver = _zNAResolver;
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function setZNSHub(IZNSHub _znsHub) external onlyOwner {
    znsHub = _znsHub;
  }

  function setZNAResolver(IZNAResolver _zNAResolver) external onlyOwner {
    zNAResolver = _zNAResolver;
  }

  function addZDAOFactory(
    IZDAORegistry.PlatformType _platformType,
    IZDAOFactory _factory
  ) external onlyOwner {
    uint256 platformType = uint256(_platformType);
    zDAOFactories[platformType] = _factory;
  }

  /**
   * @notice Add new zDAO associating with given zNA.
   *     Create new EthereumZDAO contract and associate new zDAO with given zNA.
   *     Once create new zDAO, it should be synchronized to Polygon.
   *     Users can create proposal and cast a vote after zDAO synchronization.
   * @dev Only owner can create zDAO
   * @param _platformType PlatformType enum value
   * @param _gnosisSafe Gnosis Safe address per zDAO
   * @param _name zDAO name
   * @param _options Abi encoded the structure of zDAO information
   */
  function addNewZDAO(
    uint256 _platformType,
    uint256 _zNA,
    address _gnosisSafe,
    string calldata _name,
    bytes calldata _options
  ) external override onlyZNAOwner(_zNA) {
    uint256 namePacked = uint256(keccak256(abi.encodePacked(_name)));
    require(!zDAONames[namePacked], "Already added zDAO with same name");

    IZDAOFactory factory = zDAOFactories[_platformType];
    assert(address(factory) != address(0));

    lastZDAOId++;
    address zDAO = factory.addNewZDAO(
      lastZDAOId,
      msg.sender,
      _gnosisSafe,
      _options
    );

    zDAONames[namePacked] = true;
    zDAORecords[lastZDAOId] = ZDAORecord({
      platformType: _platformType,
      id: lastZDAOId,
      gnosisSafe: _gnosisSafe,
      name: _name,
      destroyed: false
    });

    emit DAOCreated(
      _platformType,
      lastZDAOId,
      address(zDAO),
      msg.sender,
      _gnosisSafe,
      _name
    );

    // Associate zDAO with zNA, resource type = 0x1
    zNAResolver.associateWithResourceType(_zNA, 0x1, lastZDAOId);
  }

  /**
   * @notice Remove zDAO by zDAOId.
   *     Removed state should be synchronized to Polygon, so that stop
   *     user voting
   * @dev Only owner can remove zDAO, and only for valid zDAO
   * @param _zDAOId zDAO unique id
   */
  function removeZDAO(uint256 _zDAOId)
    external
    onlyValidZDAO(_zDAOId)
    onlyOwner
  {
    (uint256 platformType, ) = _removeZDAO(_zDAOId);

    emit DAODestroyed(platformType, _zDAOId);
  }

  function modifyZDAO(
    uint256 _zDAOId,
    address _gnosisSafe,
    string calldata _name,
    bytes calldata _options
  ) external onlyValidZDAO(_zDAOId) onlyOwner {
    (uint256 platformType, , ) = _modifyZDAO(
      _zDAOId,
      _gnosisSafe,
      _name,
      _options
    );

    emit DAOModified(platformType, _zDAOId, _gnosisSafe);
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal Functions                             */
  /* -------------------------------------------------------------------------- */

  function _isZDAODestroyed(uint256 _index) internal view returns (bool) {
    return zDAORecords[_index].destroyed;
  }

  function _removeZDAO(uint256 _zDAOId) internal returns (uint256, uint256) {
    ZDAORecord storage zDAORecord = zDAORecords[_zDAOId];

    IZDAOFactory factory = zDAOFactories[zDAORecord.platformType];
    assert(address(factory) != address(0));

    zDAORecord.destroyed = true;
    factory.removeZDAO(_zDAOId);

    return (zDAORecord.platformType, _zDAOId);
  }

  function _modifyZDAO(
    uint256 _zDAOId,
    address _gnosisSafe,
    string memory _name,
    bytes memory _options
  )
    internal
    returns (
      uint256,
      uint256,
      address
    )
  {
    ZDAORecord storage zDAORecord = zDAORecords[_zDAOId];

    IZDAOFactory factory = zDAOFactories[zDAORecord.platformType];
    assert(address(factory) != address(0));

    uint256 oldNamePacked = uint256(
      keccak256(abi.encodePacked(zDAORecord.name))
    );
    zDAONames[oldNamePacked] = false;
    uint256 newNamePacked = uint256(keccak256(abi.encodePacked(_name)));
    zDAONames[newNamePacked] = false;

    zDAORecord.gnosisSafe = _gnosisSafe;
    zDAORecord.name = _name;
    factory.modifyZDAO(_zDAOId, _gnosisSafe, _options);

    return (zDAORecord.platformType, _zDAOId, _gnosisSafe);
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

  function getZDAOById(uint256 _zDAOId)
    external
    view
    returns (ZDAORecord memory)
  {
    return zDAORecords[_zDAOId];
  }

  function resourceExists(uint256 _resourceID) external view returns (bool) {
    ZDAORecord storage zDAORecord = zDAORecords[_resourceID];
    return
      _resourceID > 0 && !zDAORecord.destroyed && zDAORecord.id == _resourceID;
  }
}
