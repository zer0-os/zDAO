// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

interface IZDAOFactory {
  function addNewZDAO(
    uint256 zDAOId,
    address createdBy,
    address gnosisSafe,
    bytes calldata options
  ) external returns (address);

  function removeZDAO(uint256 zDAOId) external;

  function modifyZDAO(
    uint256 zDAOId,
    address gnosisSafe,
    bytes calldata options
  ) external;
}
