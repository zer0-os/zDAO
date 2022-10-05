// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

interface IStaking {
  /* -------------------------------------------------------------------------- */
  /*                                   Events                                   */
  /* -------------------------------------------------------------------------- */

  event StakedERC20(
    address indexed user,
    address indexed token,
    uint256 indexed decimals,
    uint256 amount
  );

  event StakedERC721(
    address indexed user,
    address indexed token,
    uint256 indexed tokenId
  );

  event UnstakedERC20(
    address indexed user,
    address indexed token,
    uint256 indexed decimals,
    uint256 amount
  );

  event UnstakedERC721(
    address indexed user,
    address indexed token,
    uint256 indexed tokenId
  );

  /**
   * @dev Emitted when a token transfer or delegate change results in changes to a delegate's number of staking.
   */
  event StakingPowerChanged(
    address indexed delegate,
    address indexed token,
    uint256 oldValue,
    uint256 newValue
  );

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function stakeERC20(address token, uint256 amount) external;

  function stakeERC721(address token, uint256 tokenId) external;

  function unstakeERC20(address token, uint256 amount) external;

  function unstakeERC721(address token, uint256 tokenId) external;

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function stakingPower(address user, address token)
    external
    view
    returns (uint256);

  function pastStakingPower(
    address user,
    address token,
    uint256 blockNumber
  ) external view returns (uint256);

  function stakedERC20Amount(address user, address token)
    external
    view
    returns (uint256);

  function isStakedERC721(
    address user,
    address token,
    uint256 tokenId
  ) external view returns (bool);
}
