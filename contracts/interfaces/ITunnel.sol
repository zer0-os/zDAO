// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

interface ITunnel {
  enum MessageType {
    None,
    CreateZDAO,
    DeleteZDAO,
    CreateProposal,
    CancelProposal,
    ExecuteProposal,
    CalculateProposal,
    UpdateToken
  }
}

interface IRootStateSender is ITunnel {
  function sendMessageToChild(bytes calldata message) external;
}

interface IRootStateReceiver is ITunnel {
  function processMessageFromChild(bytes calldata message) external;
}

interface IChildStateSender is ITunnel {
  function sendMessageToRoot(bytes calldata message) external;
}

interface IChildStateReceiver is ITunnel {
  function processMessageFromRoot(bytes calldata data) external;
}
