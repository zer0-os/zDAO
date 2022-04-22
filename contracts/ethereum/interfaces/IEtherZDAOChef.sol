// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IEtherZDAO} from "./IEtherZDAO.sol";

interface IEtherZDAOChef {
  struct ZDAOConfig {
    string name;
    address gnosisSafe;
    address token; // voting token (ERC20 or ERC721)
    uint256 amount;
    uint256 minPeriod; // minimum voting period
    bool isRelativeMajority;
    uint256 threshold; // percent in 10000 as 100%
  }

  struct ZDAORecord {
    uint256 id;
    IEtherZDAO zDAO; // address to newly created ZDAO contract
    uint256[] associatedzNAs;
  }

  /* -------------------------------------------------------------------------- */
  /*                                   Events                                   */
  /* -------------------------------------------------------------------------- */

  event DAOCreated(
    uint256 indexed _daoId,
    address indexed _creator,
    address indexed _zDAO
  );

  event DAODestroyed(uint256 indexed _daoId);

  event LinkAdded(uint256 indexed _daoId, uint256 indexed _zNA);

  event LinkRemoved(uint256 indexed _daoId, uint256 indexed _zNA);

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function addNewDAO(uint256 _zNA, ZDAOConfig calldata _zDAOConfig) external;

  function removeDAO(uint256 _daoId) external;

  function addZNAAssociation(uint256 _daoId, uint256 _zNA) external;

  function removeZNAAssociation(uint256 _daoId, uint256 _zNA) external;

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function numberOfzDAOs() external view returns (uint256);

  function getzDAOById(uint256 _daoId)
    external
    view
    returns (ZDAORecord memory);

  function listzDAOs(uint256 _startIndex, uint256 _endIndex)
    external
    view
    returns (ZDAORecord[] memory);

  function getzDaoByZNA(uint256 _zNA) external view returns (ZDAORecord memory);

  function doeszDAOExistForzNA(uint256 _zNA) external view returns (bool);
}
