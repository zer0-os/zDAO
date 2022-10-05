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
    uint256 indexed platformType,
    uint256 indexed zDAOId,
    address indexed zDAO,
    address createdBy,
    address gnosisSafe,
    string name
  );

  event DAODestroyed(uint256 indexed platformType, uint256 indexed zDAOId);

  event DAOModified(
    uint256 indexed platformType,
    uint256 indexed zDAOId,
    address indexed gnosisSafe
  );

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function addNewZDAO(
    uint256 platformType,
    uint256 zNA,
    address gnosisSafe,
    string calldata title,
    bytes calldata options
  ) external;

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function zDAOFactories(uint256 platformType)
    external
    view
    returns (IZDAOFactory);

  function numberOfzDAOs() external view returns (uint256);

  function listZDAOs(uint256 startIndex, uint256 count)
    external
    view
    returns (ZDAORecord[] memory);

  function getZDAOById(uint256 zDAOId)
    external
    view
    returns (ZDAORecord memory);
}
