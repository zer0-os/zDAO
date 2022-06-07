// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

interface IZDAOFactory {
  function addNewZDAO(
    uint256 _zDAOId,
    uint256 _zNA,
    address _gnosisSafe,
    bytes calldata _options
  ) external returns (address);

  function removeZDAO(uint256 _zDAOId) external;

  function modifyZDAO(
    uint256 _zDAOId,
    address _gnosisSafe,
    bytes calldata _options
  ) external;
}
