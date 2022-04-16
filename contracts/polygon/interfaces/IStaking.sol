// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

interface IStaking {
  /* -------------------------------------------------------------------------- */
  /*                                   Events                                   */
  /* -------------------------------------------------------------------------- */

  event StakedERC20(
    address indexed _user,
    address indexed _token,
    uint256 indexed _amount,
    uint256 _totalPerUser // total staked token amount
  );

  event StakedERC721(
    address indexed _user,
    address indexed _token,
    uint256 indexed _tokenId,
    uint256 _totalPerUser // total staked token amount
  );

  event UnstakedERC20(
    address indexed _user,
    address indexed _token,
    uint256 indexed _amount,
    uint256 _totalPerUser
  );

  event UnstakedERC721(
    address indexed _user,
    address indexed _token,
    uint256 indexed _tokenId,
    uint256 _totalPerUser
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

  function totalStaked(address _token) external view returns (uint256);

  function userStaked(address _user, address _token)
    external
    view
    returns (uint256);
}
