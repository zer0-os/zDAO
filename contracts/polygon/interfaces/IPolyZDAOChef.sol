// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {IPolyZDAO} from "./IPolyZDAO.sol";

interface IPolyZDAOChef {
  /* -------------------------------------------------------------------------- */
  /*                                   Events                                   */
  /* -------------------------------------------------------------------------- */

  event DAOCreated(
    address indexed _zDAO,
    uint256 indexed _daoId,
    address indexed _token, // token address on Ethereum
    bool _isRelativeMajority,
    uint256 _threshold
  );

  event DAODestroyed(uint256 indexed _daoId);

  event ProposalCreated(
    uint256 indexed _zDAOId,
    uint256 indexed _proposalId,
    uint256 _startTimestamp,
    uint256 _endTimestamp
  );

  event CollectResult(
    uint256 indexed _zDAOId,
    uint256 indexed _proposalId,
    bool indexed _isRelativeMajority,
    uint256 _yes,
    uint256 _no
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

  function vote(
    uint256 _daoId,
    uint256 _proposalId,
    uint256 _choice
  ) external;

  function collectResult(uint256 _daoId, uint256 _proposalId) external;

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function numberOfzDAOs() external view returns (uint256);

  function getzDAOById(uint256 _daoId) external view returns (IPolyZDAO);

  function listzDAOs(uint256 _startIndex, uint256 _endIndex)
    external
    view
    returns (IPolyZDAO[] memory);
}
