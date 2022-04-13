// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "./IPolyZDAO.sol";

interface IPolyZDAOChef {
  /* -------------------------------------------------------------------------- */
  /*                                   Events                                   */
  /* -------------------------------------------------------------------------- */

  event DAOCreated(
    uint256 indexed _daoId,
    address indexed _creator,
    address indexed _zDAO
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

  // function getzDaoByZNA(uint256 _zNA) external view returns (IZDAO);

  // function doeszDAOExistForzNA(uint256 _zNA) external view returns (bool);
}
