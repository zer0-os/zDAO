// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

interface ILockable {
  /* -------------------------------------------------------------------------- */
  /*                                   Events                                   */
  /* -------------------------------------------------------------------------- */

  event Locked(
    address indexed _token,
    uint256 indexed _amount,
    uint256 indexed _lockedRepeat
  );

  event Unlocked(
    address indexed _token,
    uint256 indexed _amount,
    uint256 indexed _lockedRepeat
  );

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function lock(address _token) external;

  function unlock(address _token) external;

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function locked(address _token) external view returns (uint256);
}
