// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {IPolygonZDAO} from "./IPolygonZDAO.sol";

interface IPolygonZDAOChef {
  /* -------------------------------------------------------------------------- */
  /*                                   Events                                   */
  /* -------------------------------------------------------------------------- */

  event DAOCreated(
    address indexed _zDAO,
    uint256 indexed _zDAOId,
    uint256 _duration
  );

  event DAODestroyed(uint256 indexed _zDAOId);

  event DAOTokenUpdated(uint256 indexed _zDAOId, address indexed _token);

  event StakingUpdated(address indexed _staking);

  event DAOStakingUpdated(uint256 indexed _zDAOId, address indexed _staking);

  event ProposalCreated(
    uint256 indexed _zDAOId,
    uint256 indexed _proposalId,
    uint256 indexed _numberOfChoices,
    uint256 _proposalCreated,
    uint256 _currentTimestamp
  );

  event ProposalCanceled(uint256 indexed _zDAOId, uint256 indexed _proposalId);

  event ProposalCalculated(
    uint256 indexed _zDAOId,
    uint256 indexed _proposalId,
    uint256 _voters,
    uint256[] _votes
  );

  event CastVote(
    uint256 indexed _zDAOId,
    uint256 indexed _proposalId,
    address indexed _voter,
    uint256 _choice,
    uint256 _votingPower
  );

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function vote(
    uint256 _zDAOId,
    uint256 _proposalId,
    uint256 _choice
  ) external;

  function calculateProposal(uint256 _zDAOId, uint256 _proposalId) external;

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function getZDAOById(uint256 _zDAOId) external view returns (IPolygonZDAO);

  function getZDAOInfoById(uint256 _zDAOId)
    external
    view
    returns (IPolygonZDAO.ZDAOInfo memory);
}
