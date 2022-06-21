// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

interface IChildChainManager {
  function childToRootToken(address _child) external view returns (address);

  function rootToChildToken(address _root) external view returns (address);
}
