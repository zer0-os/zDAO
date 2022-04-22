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

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

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
