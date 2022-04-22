// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {ITunnel} from "../../interfaces/ITunnel.sol";

interface IChildTunnel is ITunnel {
  function sendMessageToRoot(bytes memory message) external;
}
