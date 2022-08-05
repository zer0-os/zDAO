// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IZDAOModule {
  
  struct Proposal {
    uint256 platformType; // 0: Snapshot, 1: Polygon
    string proposalId;
    address token; // AddressZero if transfer ether
    address to;
    uint256 amount;
    bool executed;
  }

  function grantExecutorRole(address _owner) external;

  function executeProposal(
    uint256 _platformType,
    string calldata _proposalId,
    address _token,
    address _to,
    uint256 _amount
  ) external;

  function isProposalExecuted(uint256 _platformType, string calldata _proposalId) external view returns (bool);

  event ProposalExecuted(uint256 indexed _platformType, string _proposalId, address _token, address _to, uint256 _amount);
}
