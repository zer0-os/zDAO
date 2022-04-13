// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IEtherZDAO {
  struct ZDAOInfo {
    uint256 zDAOId; // zDAO id
    address owner; // zDAO owner
    string name; // zDAO name
    address gnosisSafe;
    IERC20Upgradeable token; // voting token
    uint256 amount; // minimum voting token amount to create a proposal
    uint256 minPeriod; // minimum voting period
    bool isRelativeMajority;
    uint256 threshold; // percent in 10000 as 100%
    uint256 snapshot;
    bool destroyed;
  }

  enum ProposalState {
    Active,
    Executed,
    Deleted
  }

  struct Proposal {
    uint256 proposalId;
    address createdBy;
    uint256 startTimestamp;
    uint256 endTimestamp;
    uint256 yes;
    uint256 no;
    uint256 reserved;
    // ipfs hash: https://stackoverflow.com/questions/66927626/how-to-store-ipfs-hash-on-ethereum-blockchain-using-smart-contracts
    bytes32 ipfs;
    IERC20Upgradeable token;
    uint256 amount;
    uint256 snapshot;
    ProposalState state;
  }

  /* -------------------------------------------------------------------------- */
  /*                                   Events                                   */
  /* -------------------------------------------------------------------------- */

  event ProposalCreated(
    uint256 indexed _zDAOId,
    address indexed _proposalAuthor,
    uint256 indexed _proposalId,
    uint256 _startTimestamp,
    uint256 _endTimestamp
  );

  event ProposalExecuted(uint256 indexed _zDAOId, uint256 indexed _proposalId);

  event ProposalCollected(
    uint256 indexed _zDAOId,
    uint256 indexed _propoalId,
    uint256 yes,
    uint256 no
  );

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function setDestroyed(bool _destroyed) external;

  function createProposal(
    uint256 _startTimestamp,
    uint256 _endTimestamp,
    IERC20Upgradeable _token,
    uint256 _amount,
    bytes32 _ipfs
  ) external;

  function executeProposal(uint256 _proposalId) external;

  function setVoteResult(bytes calldata _data) external;

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function zDAOOwner() external view returns (address);

  function destroyed() external view returns (bool);

  function numberOfProposals() external view returns (uint256);

  function listProposals(uint256 _startIndex, uint256 _endIndex)
    external
    view
    returns (Proposal[] memory);
}
