// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {ZeroUpgradeable} from "../abstracts/ZeroUpgradeable.sol";
import {IZDAOFactory} from "../interfaces/IZDAOFactory.sol";

contract SnapshotZDAOChef is ZeroUpgradeable, IZDAOFactory {
  struct ZDAOInfo {
    /// @notice Unique id for looking up zDAO
    uint256 id;
    /// @notice Address who created zDAO, is the first zDAO owner
    address createdBy;
    /// @notice Snapshot block number on which zDAO has been created
    uint256 snapshot;
    /// @notice ENS name associated in snapshot
    string ensSpace;
    /// @notice Gnosis safe address where collected treasuries are stored
    address gnosisSafe;
    /// @notice Flag marking whether the zDAO has been destroyed
    bool destroyed;
  }

  // EnsId => zDAOId
  mapping(uint256 => uint256) private ensToZDAOId;
  // zDAOId => ZDAOInfo
  mapping(uint256 => ZDAOInfo) public zDAOInfos;

  address public zDAORegistry;

  /* -------------------------------------------------------------------------- */
  /*                                   Events                                   */
  /* -------------------------------------------------------------------------- */

  event DAOCreated(
    uint256 indexed _zDAOId,
    uint256 _zNA,
    address _createdBy,
    address _gnosisSafe,
    string _ensSpace
  );

  /* -------------------------------------------------------------------------- */
  /*                                  Modifiers                                 */
  /* -------------------------------------------------------------------------- */

  modifier onlyRegistry() {
    require(msg.sender == zDAORegistry, "Not a registry");
    _;
  }

  /* -------------------------------------------------------------------------- */
  /*                                 Initializer                                */
  /* -------------------------------------------------------------------------- */

  function __ZDAOChef_init(address _zDAORegistry) public initializer {
    zDAORegistry = _zDAORegistry;
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function setZDAORegistry(address _zDAORegistry) external onlyOwner {
    zDAORegistry = _zDAORegistry;
  }

  function addNewZDAO(
    uint256 _zDAOId,
    uint256 _zNA,
    address _createdBy,
    address _gnosisSafe,
    bytes calldata _options
  ) external onlyRegistry returns (address) {
    string memory ensSpace = abi.decode(_options, (string));
    uint256 ensId = _ensId(ensSpace);

    require(ensToZDAOId[ensId] == 0, "ENS already has zDAO");

    zDAOInfos[_zDAOId] = ZDAOInfo({
      id: _zDAOId,
      createdBy: _createdBy,
      snapshot: block.number,
      ensSpace: ensSpace,
      gnosisSafe: _gnosisSafe,
      destroyed: false
    });

    ensToZDAOId[ensId] = _zDAOId;

    emit DAOCreated(_zDAOId, _zNA, _createdBy, _gnosisSafe, ensSpace);

    return address(0);
  }

  function removeZDAO(uint256 _zDAOId) external onlyRegistry {
    zDAOInfos[_zDAOId].destroyed = false;
  }

  function modifyZDAO(
    uint256 _zDAOId,
    address _gnosisSafe,
    bytes calldata _options
  ) external onlyRegistry {
    string memory ensSpace = abi.decode(_options, (string));
    ZDAOInfo storage zDAO = zDAOInfos[_zDAOId];

    uint256 newEnsId = _ensId(ensSpace);
    uint256 oldEnsId = _ensId(zDAO.ensSpace);

    if (newEnsId != oldEnsId) {
      ensToZDAOId[oldEnsId] = 0;
      ensToZDAOId[newEnsId] = _zDAOId;
    }

    zDAO.ensSpace = ensSpace;
    zDAO.gnosisSafe = _gnosisSafe;
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal Functions                             */
  /* -------------------------------------------------------------------------- */

  function _ensId(string memory _ensSpace) private pure returns (uint256) {
    uint256 ensHash = uint256(keccak256(abi.encodePacked(_ensSpace)));
    return ensHash;
  }

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */
}
