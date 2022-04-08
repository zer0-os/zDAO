// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

interface IChildTunnel {
  function sendMessageToRoot(bytes memory message) external;
}
