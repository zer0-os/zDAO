// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IPolyZDAO {
  struct ZDAOInfo {
    uint256 zDAOId; // zDAO id
    // string name; // zDAO name
    // address owner; // zDAO owner
    // address token; // voting token (ERC20 or ERC721)
    address mappedToken; // mapped voting token (ERC20 or ERC721)
    // uint256 amount; // minimum voting token amount to create a proposal
    // uint256 minPeriod; // minimum voting period
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

  enum VoterChoice {
    None,
    Yes,
    No
  }

  struct Proposal {
    uint256 proposalId;
    // address createdBy;
    uint256 startTimestamp;
    uint256 endTimestamp;
    uint256 yes;
    uint256 no;
    uint256 reserved;
    // ipfs hash: https://stackoverflow.com/questions/66927626/how-to-store-ipfs-hash-on-ethereum-blockchain-using-smart-contracts
    // bytes32 ipfs;
    // IERC20Upgradeable token;
    // uint256 amount;
    uint256 snapshot;
    ProposalState state;
  }

  /* -------------------------------------------------------------------------- */
  /*                                   Events                                   */
  /* --------------------------------------------------------------------------
   */

  event ProposalCreated(
    uint256 indexed _zDAOId,
    uint256 indexed _proposalId,
    uint256 _startTimestamp,
    uint256 _endTimestamp
  );

  event CollectResult(
    uint256 indexed _zDAOId,
    uint256 indexed _proposalId,
    uint256 yes,
    uint256 no
  );

  event CastVote(
    uint256 indexed _zDAOId,
    uint256 indexed _proposalId,
    address indexed _voter,
    uint256 _choice
  );

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function setDestroyed(bool _destroyed) external;

  function createProposal(
    uint256 _proposalId,
    uint256 _startTimestamp,
    uint256 _endTimestamp
  ) external;

  function vote(uint256 _proposalId, VoterChoice _choice) external;

  function collectResult(uint256 _proposalId) external;

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function zDAOId() external view returns (uint256);

  function destroyed() external view returns (bool);

  function numberOfProposals() external view returns (uint256);

  function listProposals(uint256 _startIndex, uint256 _endIndex)
    external
    view
    returns (Proposal[] memory);

  function canVote(uint256 _proposalId, address _voter)
    external
    view
    returns (bool);

  function canCollectResult(uint256 _proposalId) external view returns (bool);

  function getVoterChoice(uint256 _proposalId, address _voter)
    external
    view
    returns (VoterChoice);
}
