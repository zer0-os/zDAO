// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {ZeroUpgradeable} from "./abstracts/ZeroUpgradeable.sol";
import {IResourceRegistry} from "./interfaces/IResourceRegistry.sol";
import {IZDAOFactory} from "./interfaces/IZDAOFactory.sol";
import {IZDAORegistry} from "./interfaces/IZDAORegistry.sol";
import {IZNAResolver} from "./interfaces/IZNAResolver.sol";
import {IZNSHub} from "./interfaces/IZNSHub.sol";
import {ResourceType} from "./libraries/ResourceType.sol";

contract ZDAORegistry is ZeroUpgradeable, IZDAORegistry, IResourceRegistry {
  IZNSHub public zNSHub;

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

  modifier onlyZNAOwner(uint256 zNA) {
    require(zNSHub.ownerOf(zNA) == msg.sender, "Not a zNA owner");
    _;
  }

  modifier onlyValidZDAO(uint256 zDAOId) {
    require(
      zDAOId > 0 && zDAOId <= lastZDAOId && !_isZDAODestroyed(zDAOId),
      "Invalid zDAO"
    );
    _;
  }

  /* -------------------------------------------------------------------------- */
  /*                                 Initializer                                */
  /* -------------------------------------------------------------------------- */

  function __ZDAORegistry_init(IZNSHub zNSHub_, IZNAResolver zNAResolver_)
    public
    initializer
  {
    ZeroUpgradeable.__ZeroUpgradeable_init();

    zNSHub = zNSHub_;
    zNAResolver = zNAResolver_;
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function setZNSHub(IZNSHub zNSHub_) external onlyOwner {
    zNSHub = zNSHub_;
  }

  function setZNAResolver(IZNAResolver zNAResolver_) external onlyOwner {
    zNAResolver = zNAResolver_;
  }

  function addZDAOFactory(
    IZDAORegistry.PlatformType platformType,
    IZDAOFactory factory
  ) external onlyOwner {
    zDAOFactories[uint256(platformType)] = factory;
  }

  /**
   * @notice Add new zDAO associating with given zNA.
   *     Create new EthereumZDAO contract and associate new zDAO with given zNA.
   *     Once create new zDAO, it should be synchronized to Polygon.
   *     Users can create proposal and cast a vote after zDAO synchronization.
   * @dev Only owner can create zDAO
   * @param platformType PlatformType enum value
   * @param gnosisSafe Gnosis Safe address per zDAO
   * @param name zDAO name
   * @param options Abi encoded the structure of zDAO information
   */
  function addNewZDAO(
    uint256 platformType,
    uint256 zNA,
    address gnosisSafe,
    string calldata name,
    bytes calldata options
  ) external override onlyZNAOwner(zNA) {
    uint256 namePacked = uint256(keccak256(abi.encodePacked(name)));
    require(!zDAONames[namePacked], "Already added zDAO with same name");

    IZDAOFactory factory = zDAOFactories[platformType];
    assert(address(factory) != address(0));

    lastZDAOId++;
    address zDAO = factory.addNewZDAO(
      lastZDAOId,
      msg.sender,
      gnosisSafe,
      options
    );

    zDAONames[namePacked] = true;
    zDAORecords[lastZDAOId] = ZDAORecord({
      platformType: platformType,
      id: lastZDAOId,
      gnosisSafe: gnosisSafe,
      name: name,
      destroyed: false
    });

    emit DAOCreated(
      platformType,
      lastZDAOId,
      address(zDAO),
      msg.sender,
      gnosisSafe,
      name
    );

    // Associate zDAO with zNA
    zNAResolver.associateWithResourceType(
      zNA,
      ResourceType.RESOURCE_TYPE_DAO,
      lastZDAOId
    );
  }

  /**
   * @notice Remove zDAO by zDAOId.
   *     Removed state should be synchronized to Polygon, so that stop
   *     user voting
   * @dev Only owner can remove zDAO, and only for valid zDAO
   * @param zDAOId zDAO unique id
   */
  function removeZDAO(uint256 zDAOId)
    external
    onlyValidZDAO(zDAOId)
    onlyOwner
  {
    (uint256 platformType, ) = _removeZDAO(zDAOId);

    emit DAODestroyed(platformType, zDAOId);
  }

  function modifyZDAO(
    uint256 zDAOId,
    address gnosisSafe,
    string calldata name,
    bytes calldata options
  ) external onlyValidZDAO(zDAOId) onlyOwner {
    (uint256 platformType, , ) = _modifyZDAO(
      zDAOId,
      gnosisSafe,
      name,
      options
    );

    emit DAOModified(platformType, zDAOId, gnosisSafe);
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal Functions                             */
  /* -------------------------------------------------------------------------- */

  function _isZDAODestroyed(uint256 index) internal view returns (bool) {
    return zDAORecords[index].destroyed;
  }

  function _removeZDAO(uint256 zDAOId) internal returns (uint256, uint256) {
    ZDAORecord storage zDAORecord = zDAORecords[zDAOId];

    IZDAOFactory factory = zDAOFactories[zDAORecord.platformType];
    assert(address(factory) != address(0));

    zDAORecord.destroyed = true;
    factory.removeZDAO(zDAOId);

    return (zDAORecord.platformType, zDAOId);
  }

  function _modifyZDAO(
    uint256 zDAOId,
    address gnosisSafe,
    string memory name,
    bytes memory options
  )
    internal
    returns (
      uint256,
      uint256,
      address
    )
  {
    ZDAORecord storage zDAORecord = zDAORecords[zDAOId];

    IZDAOFactory factory = zDAOFactories[zDAORecord.platformType];
    assert(address(factory) != address(0));

    uint256 oldNamePacked = uint256(
      keccak256(abi.encodePacked(zDAORecord.name))
    );
    zDAONames[oldNamePacked] = false;
    uint256 newNamePacked = uint256(keccak256(abi.encodePacked(name)));
    zDAONames[newNamePacked] = false;

    zDAORecord.gnosisSafe = gnosisSafe;
    zDAORecord.name = name;
    factory.modifyZDAO(zDAOId, gnosisSafe, options);

    return (zDAORecord.platformType, zDAOId, gnosisSafe);
  }

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function numberOfzDAOs() external view override returns (uint256) {
    return lastZDAOId;
  }

  function listZDAOs(uint256 startIndex, uint256 count)
    external
    view
    override
    returns (ZDAORecord[] memory records)
  {
    uint256 numRecords = count;
    if (numRecords > (lastZDAOId - startIndex)) {
      numRecords = lastZDAOId - startIndex;
    }

    records = new ZDAORecord[](numRecords);

    for (uint256 i = 0; i < numRecords; ++i) {
      records[i] = zDAORecords[startIndex + i + 1];
    }

    return records;
  }

  function getZDAOById(uint256 zDAOId)
    external
    view
    returns (ZDAORecord memory)
  {
    return zDAORecords[zDAOId];
  }

  function resourceExists(uint256 resourceID) external view returns (bool) {
    ZDAORecord storage zDAORecord = zDAORecords[resourceID];
    return
      resourceID > 0 && !zDAORecord.destroyed && zDAORecord.id == resourceID;
  }
}
