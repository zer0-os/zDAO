// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {IERC20Upgradeable} from "../../../oz-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IPolygonZDAO {
  struct ZDAOInfo {
    /// @notice Unique id for looking up zDAO
    uint256 zDAOId;
    /// @notice Time duration of this proposal in seconds
    uint256 duration;
    /// @notice Delay of proposal to start voting in seconds, optional
    uint256 votingDelay;
    /// @notice Voting token on Polygon
    address token;
    /// @notice Snapshot block number on which zDAO has been created
    uint256 snapshot;
    /// @notice Flag marking whether the zDAO has been destroyed
    bool destroyed;
  }

  enum ProposalState {
    Pending,
    Active,
    Canceled,
    AwaitingCalculation,
    Closed
  }

  struct Proposal {
    /// @notice Unique id for looking up proposal
    uint256 proposalId;
    /// @notice Number of choices
    uint256 numberOfChoices;
    /// @notice Timestamp when the proposal starts
    uint256 startTimestamp;
    /// @notice Timestamp when the proposal ends
    uint256 endTimestamp;
    /// @notice The number of voters who votes
    uint256 voters;
    /// @notice Snapshot block number on which proposal has been created
    uint256 snapshot;
    /// @notice Flag marking whether this proposal has been calculated
    bool calculated;
    /// @notice Flag marking whether this proposal has been canceled
    bool canceled;
    /// @notice The number of all the casted votes with given choice
    uint256[] votes;
  }

  struct Vote {
    /// @notice Voter address
    address voter;
    /// @notice The choice the voter chosed, which were cast
    uint256 choice;
    /// @notice The number of votes the voter had, which were cast
    uint256 votes;
  }

  struct ProposalVotes {
    /// @notice Array of voters who casted
    address[] voters;
    /// @notice The set of votes for whole voters
    mapping(address => Vote) votes;
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function __ZDAO_init(
    address zDAOChef,
    address staking,
    uint256 zDAOId,
    uint256 duration,
    uint256 votingDelay,
    address token
  ) external;

  function setDestroyed(bool destroyed) external;

  function setStaking(address staking) external;

  function updateToken(address token) external;

  function createProposal(
    uint256 proposalId,
    uint256 numberOfChoices,
    uint256 startTimestamp
  ) external;

  function cancelProposal(uint256 proposalId) external;

  function calculateProposal(uint256 proposalId)
    external
    returns (uint256 voters, uint256[] memory votes);

  function vote(
    uint256 proposalId,
    address voter,
    uint256 choice
  ) external returns (uint256);

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function getZDAOId() external view returns (uint256);

  function getZDAOInfo() external view returns (ZDAOInfo memory);

  function destroyed() external view returns (bool);

  function numberOfProposals() external view returns (uint256);

  function getProposalById(uint256 proposalId)
    external
    view
    returns (Proposal memory);

  function listProposals(uint256 startIndex, uint256 count)
    external
    view
    returns (Proposal[] memory records);

  function state(uint256 proposalId) external view returns (ProposalState);

  function votesResultOfProposal(uint256 proposalId)
    external
    view
    returns (uint256 voters, uint256[] memory votes);

  function canVote(uint256 proposalId, address voter)
    external
    view
    returns (bool);

  function canCalculateProposal(uint256 proposalId)
    external
    view
    returns (bool);

  function choiceOfVoter(uint256 proposalId, address voter)
    external
    view
    returns (uint256);

  function votingPowerOfVoter(uint256 proposalId, address voter)
    external
    view
    returns (uint256);

  function listVoters(
    uint256 proposalId,
    uint256 startIndex,
    uint256 endIndex
  )
    external
    view
    returns (
      address[] memory voters,
      uint256[] memory choices,
      uint256[] memory votes
    );
}
