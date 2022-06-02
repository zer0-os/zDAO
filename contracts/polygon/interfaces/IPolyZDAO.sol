// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {IERC20Upgradeable} from "../../oz-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IPolyZDAO {
  struct ZDAOInfo {
    /// @notice Unique id for looking up zDAO
    uint256 zDAOId;
    /// @notice Time duration of this proposal in seconds
    uint256 duration;
    /// @notice Voting token on Polygon
    address token;
    /// @notice Snapshot block number on which zDAO has been created
    uint256 snapshot;
    /// @notice Flag marking whether the zDAO has been destroyed
    bool destroyed;
  }

  enum VoterChoice {
    None,
    Yes,
    No
  }

  enum ProposalState {
    Pending,
    Active,
    Canceled,
    Executed,
    Calculating,
    Calculated
  }

  struct Proposal {
    /// @notice Unique id for looking up proposal
    uint256 proposalId;
    /// @notice Timestamp when the proposal starts
    uint256 startTimestamp;
    /// @notice Timestamp when the proposal ends
    uint256 endTimestamp;
    /// @notice The number of calculated voting power in favor of this proposal
    uint256 yes;
    /// @notice The number of calculated voting power in opposition to this proposal
    uint256 no;
    /// @notice The number of voters who votes
    uint256 voters;
    /// @notice Snapshot block number on which proposal has been created
    uint256 snapshot;
    /// @notice Flag marking whether this proposal has been calculated
    bool calculated;
    /// @notice Flag marking whether this proposal has been executed
    bool executed;
    /// @notice Flag marking whether this proposal has been canceled
    bool canceled;
  }

  struct Vote {
    /// @notice Voter address
    address voter;
    /// @notice The choice the voter chosed, which were cast
    VoterChoice choice;
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
    address _zDAOChef,
    address _staking,
    uint256 _zDAOId,
    uint256 _duration,
    address _token
  ) external;

  function setDestroyed(bool _destroyed) external;

  function updateToken(address _token) external;

  function createProposal(uint256 _proposalId, uint256 _startTimestamp)
    external;

  function cancelProposal(uint256 _proposalId) external;

  function executeProposal(uint256 _proposalId) external;

  function calculateProposal(uint256 _proposalId)
    external
    returns (
      uint256 voters,
      uint256 yes,
      uint256 no
    );

  function vote(
    uint256 _proposalId,
    address _voter,
    uint256 _choice
  ) external;

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function zDAOId() external view returns (uint256);

  function destroyed() external view returns (bool);

  function numberOfProposals() external view returns (uint256);

  function listProposals(uint256 _startIndex, uint256 _count)
    external
    view
    returns (Proposal[] memory records);

  function state(uint256 _proposalId) external view returns (ProposalState);

  function votesResultOfProposal(uint256 _proposalId)
    external
    view
    returns (
      uint256 voters,
      uint256 yes,
      uint256 no
    );

  function canVote(uint256 _proposalId, address _voter)
    external
    view
    returns (bool);

  function canCalculateProposal(uint256 _proposalId)
    external
    view
    returns (bool);

  function choiceOfVoter(uint256 _proposalId, address _voter)
    external
    view
    returns (VoterChoice);

  function votingPowerOfVoter(uint256 _proposalId, address _voter)
    external
    view
    returns (uint256);

  function listVoters(
    uint256 _proposalId,
    uint256 _startIndex,
    uint256 _endIndex
  )
    external
    view
    returns (
      address[] memory voters,
      uint256[] memory choices,
      uint256[] memory votes
    );
}
