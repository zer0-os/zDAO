// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {IERC20Upgradeable} from "../../../oz-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IEthereumZDAO} from "./IEthereumZDAO.sol";

interface IEthereumZDAOChef {
  struct ZDAOConfig {
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
    /// @notice True if relative majority to calculate voting result
    bool isRelativeMajority;
  }

  /* -------------------------------------------------------------------------- */
  /*                                   Events                                   */
  /* -------------------------------------------------------------------------- */

  event ProposalCreated(
    uint256 indexed _zDAOId,
    uint256 indexed _proposalId,
    uint256 indexed _numberOfChoices,
    address _createdBy,
    uint256 _snapshot
  );

  event ProposalCanceled(
    uint256 indexed _zDAOId,
    uint256 indexed _proposalId,
    address indexed _cancelBy
  );

  event ProposalExecuted(
    uint256 indexed _zDAOId,
    uint256 indexed _proposalId,
    address indexed _executeBy
  );

  event ProposalCalculated(
    uint256 indexed _zDAOId,
    uint256 indexed _propoalId,
    uint256 _voters,
    uint256[] votes
  );

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function createProposal(
    uint256 _zDAOId,
    string[] calldata _choices,
    string calldata _ipfs
  ) external;

  function cancelProposal(uint256 _zDAOId, uint256 _proposalId) external;

  function executeProposal(uint256 _zDAOId, uint256 _proposalId) external;

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function getZDAOById(uint256 _zDAOId) external view returns (IEthereumZDAO);

  function getZDAOInfoById(uint256 _zDAOId)
    external
    view
    returns (IEthereumZDAO.ZDAOInfo memory);
}
