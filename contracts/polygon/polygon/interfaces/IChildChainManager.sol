// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

interface IChildChainManager {
  function childToRootToken(address child) external view returns (address);

  function rootToChildToken(address root) external view returns (address);
}
