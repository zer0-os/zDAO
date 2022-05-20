// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

interface IStaking {
  /* -------------------------------------------------------------------------- */
  /*                                   Events                                   */
  /* -------------------------------------------------------------------------- */

  event StakedERC20(
    address indexed _user,
    address indexed _token,
    uint256 indexed _amount
  );

  event StakedERC721(
    address indexed _user,
    address indexed _token,
    uint256 indexed _tokenId
  );

  event UnstakedERC20(
    address indexed _user,
    address indexed _token,
    uint256 indexed _amount
  );

  event UnstakedERC721(
    address indexed _user,
    address indexed _token,
    uint256 indexed _tokenId
  );

  /**
   * @dev Emitted when a token transfer or delegate change results in changes to a delegate's number of staking.
   */
  event StakingPowerChanged(
    address indexed _delegate,
    address indexed _token,
    uint256 _oldValue,
    uint256 _newValue
  );

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function stakeERC20(address _token, uint256 _amount) external;

  function stakeERC721(address _token, uint256 _tokenId) external;

  function unstakeERC20(address _token, uint256 _amount) external;

  function unstakeERC721(address _token, uint256 _tokenId) external;

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function stakingPower(address _user, address _token)
    external
    view
    returns (uint256);

  function pastStakingPower(
    address _user,
    address _token,
    uint256 _blockNumber
  ) external view returns (uint256);
}
