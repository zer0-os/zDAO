// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "../../interfaces/ITunnel.sol";

interface IRootTunnel is ITunnel {
  function sendMessageToChild(bytes memory message) external;
}
