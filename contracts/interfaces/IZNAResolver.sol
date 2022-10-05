// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

interface IZNAResolver {
  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function associateWithResourceType(
    uint256 zNA,
    uint256 resourceType,
    uint256 resourceID
  ) external;

  function disassociateWithResourceType(uint256 zNA, uint256 resourceType)
    external;

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function hasResourceType(uint256 zNA, uint256 resourceType)
    external
    view
    returns (bool);

  function resourceTypes(uint256 zNA) external view returns (uint256);

  function resourceID(uint256 zNA, uint256 resourceType)
    external
    view
    returns (uint256);
}
