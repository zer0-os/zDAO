// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {IERC20Upgradeable} from "../../../oz-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IEthereumZDAOChef} from "./IEthereumZDAOChef.sol";

interface IEthereumZDAO {
  struct ZDAOInfo {
    /// @notice Unique id for looking up zDAO
    uint256 zDAOId; // zDAO id
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
    /// @notice Delay of proposal to start voting in seconds, optional
    uint256 votingDelay;
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
    Closed
  }

  struct Proposal {
    /// @notice Unique id for looking up proposal
    uint256 proposalId;
    /// @notice Address who created proposal
    address createdBy;
    /// @notice Timestamp when the proposal was created
    uint256 created;
    /// @notice The number of voters who votes
    uint256 voters;
    /// @notice IPFS hash which contains meta information of this proposal
    string ipfs;
    /// @notice Snapshot block number on which proposal has been created
    uint256 snapshot;
    /// @notice Flag marking whether this proposal has been calculated
    bool calculated;
    /// @notice Flag marking whether this proposal has been canceled
    bool canceled;
    /// @notice Arrays of choices
    string[] choices;
    /// @notice The number of all the casted votes with given choice
    uint256[] votes;
  }

  /* -------------------------------------------------------------------------- */
  /*                                   Events                                   */
  /* -------------------------------------------------------------------------- */

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function __ZDAO_init(
    address zDAOChef,
    uint256 zDAOId,
    address gnosisSafe,
    address createdBy,
    IEthereumZDAOChef.ZDAOConfig calldata zDAOConfig
  ) external;

  function setDestroyed(bool destroyed) external;

  function modifyZDAO(
    address gnosisSafe,
    address token,
    uint256 amount
  ) external;

  function createProposal(
    address createdBy,
    string[] calldata choices,
    string calldata ipfs
  ) external returns (uint256);

  function cancelProposal(address cancelBy, uint256 proposalid) external;

  function calculateProposal(
    uint256 proposalId,
    uint256 voters,
    uint256[] calldata votes
  ) external;

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function getZDAOId() external view returns (uint256);

  function getZDAOInfo() external view returns (ZDAOInfo memory);

  function getZDAOOwner() external view returns (address);

  function destroyed() external view returns (bool);

  function numberOfProposals() external view returns (uint256);

  function getProposalById(uint256 proposalId)
    external
    view
    returns (Proposal memory);

  function listProposals(uint256 startIndex, uint256 count)
    external
    view
    returns (Proposal[] memory);

  function state(uint256 proposalId) external view returns (ProposalState);
}
