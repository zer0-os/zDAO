// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {IZDAOFactory} from "./IZDAOFactory.sol";

interface IZDAORegistry {
  enum PlatformType {
    Snapshot,
    Polygon
  }

  struct ZDAORecord {
    /// @notice PlatformType enumeration as uint256
    uint256 platformType;
    /// @notice Unique id for looking up zDAO
    uint256 id;
    /// @notice Gnosis safe address where collected treasuries are stored
    address gnosisSafe;
    /// @notice zDAO name
    string name;
    /// @notice Flag marking whether the zDAO has been destroyed
    bool destroyed;
  }

  /* -------------------------------------------------------------------------- */
  /*                                   Events                                   */
  /* -------------------------------------------------------------------------- */

  event DAOCreated(
    uint256 indexed _platformType,
    uint256 indexed _zDAOId,
    address indexed _zDAO,
    address _createdBy,
    address _gnosisSafe,
    string _name
  );

  event DAODestroyed(uint256 indexed _platformType, uint256 indexed _zDAOId);

  event DAOModified(
    uint256 indexed _platformType,
    uint256 indexed _zDAOId,
    address indexed _gnosisSafe
  );

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function addNewZDAO(
    uint256 _platformType,
    uint256 _zNA,
    address _gnosisSafe,
    string calldata _title,
    bytes calldata _options
  ) external;

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function zDAOFactories(uint256 _platformType)
    external
    view
    returns (IZDAOFactory);

  function numberOfzDAOs() external view returns (uint256);

  function listZDAOs(uint256 _startIndex, uint256 _count)
    external
    view
    returns (ZDAORecord[] memory);

  function getZDAOById(uint256 _zDAOId)
    external
    view
    returns (ZDAORecord memory);
}
