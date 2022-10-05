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

  event DAOCreated(
    uint256 indexed zDAOId,
    address indexed zDAO,
    address indexed createdBy,
    address gnosisSafe,
    address token,
    uint256 amount,
    uint256 duration,
    uint256 votingDelay,
    uint256 votingThreshold,
    uint256 minimumVotingParticipants,
    uint256 minimumTotalVotingTokens,
    bool isRelativeMajority
  );

  event ProposalCreated(
    uint256 indexed zDAOId,
    uint256 indexed proposalId,
    uint256 indexed numberOfChoices,
    address createdBy,
    uint256 snapshot,
    string ipfs
  );

  event ProposalCanceled(
    uint256 indexed zDAOId,
    uint256 indexed proposalId,
    address indexed cancelBy
  );

  event ProposalCalculated(
    uint256 indexed zDAOId,
    uint256 indexed proposalId,
    uint256 voters,
    uint256[] votes
  );

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function setZDAORegistry(address zDAORgistry) external;

  function setZDAOBase(address zDAOBase) external;

  function createProposal(
    uint256 zDAOId,
    string[] calldata choices,
    string calldata ipfs
  ) external;

  function cancelProposal(uint256 zDAOId, uint256 proposalId) external;

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function getZDAOById(uint256 zDAOId) external view returns (IEthereumZDAO);

  function getZDAOInfoById(uint256 zDAOId)
    external
    view
    returns (IEthereumZDAO.ZDAOInfo memory);
}
