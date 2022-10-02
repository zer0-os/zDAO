// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IZNAResolver {
  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function associateWithResourceType(
    uint256 _zNA,
    uint256 _resourceType,
    uint256 _resourceID
  ) external;

  function disassociateWithResourceType(uint256 _zNA, uint256 _resourceType)
    external;

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function hasResourceType(uint256 _zNA, uint256 _resourceType)
    external
    view
    returns (bool);

  function resourceTypes(uint256 _zNA) external view returns (uint256);

  function resourceID(uint256 _zNA, uint256 _resourceType)
    external
    view
    returns (uint256);
}
