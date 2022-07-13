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

interface IEthereumStateSender is ITunnel {
  function sendMessageToChild(bytes calldata message) external;
}

interface IEthereumStateReceiver is ITunnel {
  function processMessageFromChild(bytes calldata message) external;
}

interface IPolygonStateSender is ITunnel {
  function sendMessageToRoot(bytes calldata message) external;
}

interface IPolygonStateReceiver is ITunnel {
  function processMessageFromRoot(bytes calldata data) external;
}
