// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

interface IRootTunnel {
  function sendMessageToChild(bytes memory message) external;
}
