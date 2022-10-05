// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {IPolygonZDAO} from "./IPolygonZDAO.sol";

interface IPolygonZDAOChef {
  /* -------------------------------------------------------------------------- */
  /*                                   Events                                   */
  /* -------------------------------------------------------------------------- */

  event DAOCreated(
    address indexed zDAO,
    uint256 indexed zDAOId,
    address indexed token,
    uint256 duration,
    uint256 votingDelay
  );

  event DAODestroyed(uint256 indexed zDAOId);

  event DAOTokenUpdated(uint256 indexed zDAOId, address indexed token);

  event StakingUpdated(address indexed staking);

  event DAOStakingUpdated(uint256 indexed zDAOId, address indexed staking);

  event ProposalCreated(
    uint256 indexed zDAOId,
    uint256 indexed proposalId,
    uint256 indexed numberOfChoices,
    uint256 proposalCreated,
    uint256 currentTimestamp
  );

  event ProposalCanceled(uint256 indexed zDAOId, uint256 indexed proposalId);

  event ProposalCalculated(
    uint256 indexed zDAOId,
    uint256 indexed proposalId,
    uint256 voters,
    uint256[] votes
  );

  event CastVote(
    uint256 indexed zDAOId,
    uint256 indexed proposalId,
    address indexed voter,
    uint256 choice,
    uint256 votingPower
  );

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function vote(
    uint256 zDAOId,
    uint256 proposalId,
    uint256 choice
  ) external;

  function calculateProposal(uint256 zDAOId, uint256 proposalId) external;

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function getZDAOById(uint256 zDAOId) external view returns (IPolygonZDAO);

  function getZDAOInfoById(uint256 zDAOId)
    external
    view
    returns (IPolygonZDAO.ZDAOInfo memory);
}
