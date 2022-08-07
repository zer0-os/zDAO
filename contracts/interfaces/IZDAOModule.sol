// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IZDAOModule {
  struct Proposal {
    uint256 platformType; // 0: Snapshot, 1: Polygon
    uint256 proposalHash;
    address token; // AddressZero if transfer ether
    address to;
    uint256 amount;
    bool executed;
  }

  function executeProposal(
    uint256 _platformType,
    uint256 _proposalHash,
    address _token,
    address _to,
    uint256 _amount
  ) external;

  function isProposalExecuted(uint256 _platformType, uint256 _proposalHash)
    external
    view
    returns (bool);

  event ProposalExecuted(
    uint256 indexed _platformType,
    uint256 _proposalHash,
    address _token,
    address _to,
    uint256 _amount
  );
}
