// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {IERC20Upgradeable} from "../../../oz-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IRootZDAOChef} from "./IRootZDAOChef.sol";

interface IRootZDAO {
  struct ZDAOInfo {
    /// @notice Unique id for looking up zDAO
    uint256 zDAOId; // zDAO id
    /// @notice Title of the zDAO
    string title;
    /// @notice Address who created zDAO, is the first zDAO owner
    address createdBy;
    /// @notice Gnosis safe address where collected treasuries are stored
    address gnosisSafe;
    /// @notice Voting token (ERC20 or ERC721) on Ethereum, only token holders
    /// can create a proposal
    address token;
    /// @notice The minimum number of tokens required to become proposal creator
    uint256 amount;
    /// @notice Time duration of this proposal in seconds
    uint256 duration;
    /// @notice Voting threshold in 100% as 10000 required to check if proposal is succeeded
    uint256 votingThreshold;
    /// @notice The number of voters in support of a proposal required in order
    /// for a vote to succeed
    uint256 minimumVotingParticipants;
    /// @notice The number of votes in support of a proposal required in order
    /// for a vote to succeed
    uint256 minimumTotalVotingTokens;
    /// @notice Snapshot block number on which zDAO has been created
    uint256 snapshot;
    /// @notice True if relative majority to calculate voting result
    bool isRelativeMajority;
    /// @notice Flag marking whether the zDAO has been destroyed
    bool destroyed;
  }

  enum ProposalState {
    Pending,
    Active,
    Canceled,
    Executed,
    Failed,
    Succeeded
  }

  struct Proposal {
    /// @notice Unique id for looking up proposal
    uint256 proposalId;
    /// @notice Address who created proposal
    address createdBy;
    /// @notice Timestamp when the proposal was created
    uint256 created;
    /// @notice The number of all the casted votes in favor of this proposal
    uint256 yes;
    /// @notice The number of all the casted vote in opposition to this proposal
    uint256 no;
    /// @notice The number of voters who votes
    uint256 voters;
    /// @notice IPFS hash which contains meta information of this proposal
    string ipfs;
    /// @notice Snapshot block number on which proposal has been created
    uint256 snapshot;
    /// @notice Flag marking whether this proposal has been calculated
    bool calculated;
    /// @notice Flag marking whether this proposal has been executed
    bool executed;
    /// @notice Flag marking whether this proposal has been canceled
    bool canceled;
  }

  /* -------------------------------------------------------------------------- */
  /*                                   Events                                   */
  /* -------------------------------------------------------------------------- */

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function __ZDAO_init(
    address _zDAOChef,
    uint256 _zDAOId,
    address _gnosisSafe,
    address _createdBy,
    string calldata _title,
    IRootZDAOChef.ZDAOConfig calldata _zDAOConfig
  ) external;

  function setDestroyed(bool _destroyed) external;

  function modifyZDAO(
    address _gnosisSafe,
    address _token,
    uint256 _amount
  ) external;

  function createProposal(address _createdBy, string calldata _ipfs)
    external
    returns (uint256);

  function cancelProposal(address _cancelBy, uint256 _proposalid) external;

  function executeProposal(address _executeBy, uint256 _proposalId) external;

  function calculateProposal(
    uint256 _proposalId,
    uint256 _voters,
    uint256 _yes,
    uint256 _no
  ) external;

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function zDAOOwner() external view returns (address);

  function destroyed() external view returns (bool);

  function numberOfProposals() external view returns (uint256);

  function listProposals(uint256 _startIndex, uint256 _count)
    external
    view
    returns (Proposal[] memory);

  function state(uint256 _proposalId) external view returns (ProposalState);
}
