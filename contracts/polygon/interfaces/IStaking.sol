// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

interface IStaking {
  /* -------------------------------------------------------------------------- */
  /*                                   Events                                   */
  /* -------------------------------------------------------------------------- */

  event Staked(
    address indexed _user,
    address indexed _token,
    uint256 indexed _amount,
    uint256 _totalPerUser
  );

  event Unstaked(
    address indexed _user,
    address indexed _token,
    uint256 indexed _amount,
    uint256 _totalPerUser
  );

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function stake(
    address _user,
    address _token,
    uint256 _amount
  ) external;

  function unstake(
    address _user,
    address _token,
    uint256 _amount
  ) external;

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function totalStaked(address _token) external view returns (uint256);

  function userStaked(address _user, address _token)
    external
    view
    returns (uint256);
}
