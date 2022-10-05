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
    uint256 indexed zDAOId,
    address indexed createdBy,
    address gnosisSafe,
    string ensSpace
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

  function __ZDAOChef_init(address zDAORegistry_) public initializer {
    zDAORegistry = zDAORegistry_;
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function setZDAORegistry(address zDAORegistry_) external onlyOwner {
    zDAORegistry = zDAORegistry_;
  }

  function addNewZDAO(
    uint256 zDAOId,
    address createdBy,
    address gnosisSafe,
    bytes calldata options
  ) external onlyRegistry returns (address) {
    string memory ensSpace = abi.decode(options, (string));
    uint256 ensId = _ensId(ensSpace);

    require(ensToZDAOId[ensId] == 0, "ENS already has zDAO");

    zDAOInfos[zDAOId] = ZDAOInfo({
      id: zDAOId,
      createdBy: createdBy,
      snapshot: block.number,
      ensSpace: ensSpace,
      gnosisSafe: gnosisSafe,
      destroyed: false
    });

    ensToZDAOId[ensId] = zDAOId;

    emit DAOCreated(zDAOId, createdBy, gnosisSafe, ensSpace);

    return address(0);
  }

  function removeZDAO(uint256 zDAOId) external onlyRegistry {
    zDAOInfos[zDAOId].destroyed = false;
  }

  function modifyZDAO(
    uint256 zDAOId,
    address gnosisSafe,
    bytes calldata options
  ) external onlyRegistry {
    string memory ensSpace = abi.decode(options, (string));
    ZDAOInfo storage zDAO = zDAOInfos[zDAOId];

    uint256 newEnsId = _ensId(ensSpace);
    uint256 oldEnsId = _ensId(zDAO.ensSpace);

    if (newEnsId != oldEnsId) {
      ensToZDAOId[oldEnsId] = 0;
      ensToZDAOId[newEnsId] = zDAOId;
    }

    zDAO.ensSpace = ensSpace;
    zDAO.gnosisSafe = gnosisSafe;
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal Functions                             */
  /* -------------------------------------------------------------------------- */

  function _ensId(string memory ensSpace) private pure returns (uint256) {
    uint256 ensHash = uint256(keccak256(abi.encodePacked(ensSpace)));
    return ensHash;
  }

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */
}
