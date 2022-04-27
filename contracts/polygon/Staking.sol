// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {console} from "hardhat/console.sol";
import {IERC721Upgradeable} from "../oz-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import {ERC721HolderUpgradeable} from "../oz-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import {ERC165CheckerUpgradeable} from "../oz-upgradeable/utils/introspection/ERC165CheckerUpgradeable.sol";
import "../oz-upgradeable/utils/Checkpoints.sol";
import {ZeroUpgradeable, SafeERC20Upgradeable, IERC20Upgradeable} from "../abstracts/ZeroUpgradeable.sol";
import {IStaking} from "./interfaces/IStaking.sol";

contract Staking is ZeroUpgradeable, IStaking, ERC721HolderUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;
  using ERC165CheckerUpgradeable for address;
  using Checkpoints for Checkpoints.History;

  struct Account {
    address user;
    // <IERC20, token amount>
    // <IERC721, token id>
    mapping(address => uint256) staked;
  }

  // <user addres, <IERC20, Account>>
  // <user addres, <IERC721, Account>>
  mapping(address => Account) public accounts;

  // <user address, Checkpoints.History>
  mapping(address => Checkpoints.History) private _checkpoints;
  Checkpoints.History private _totalCheckpoints;

  /* -------------------------------------------------------------------------- */
  /*                                  Modifiers                                 */
  /* -------------------------------------------------------------------------- */

  /* -------------------------------------------------------------------------- */
  /*                                 Initializer                                */
  /* -------------------------------------------------------------------------- */

  function __Staking_init() public initializer {
    ZeroUpgradeable.__ZeroUpgradeable_init();
    __ERC721Holder_init();
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function stakeERC20(address _token, uint256 _amount) external {
    require(!_isERC721(_token), "Should ERC20 token address");
    _stakeERC20(msg.sender, _token, _amount);
  }

  function stakeERC721(address _token, uint256 _tokenId) external {
    require(_isERC721(_token), "Should ERC721 token address");
    _stakeERC721(msg.sender, _token, _tokenId);
  }

  function unstakeERC20(address _token, uint256 _amount) external {
    _unstakeERC20(msg.sender, _token, _amount);
  }

  function unstakeERC721(address _token, uint256 _tokenId) external {
    _unstakeERC721(msg.sender, _token, _tokenId);
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal Functions                             */
  /* -------------------------------------------------------------------------- */

  function _isERC721(address _token) internal view returns (bool) {
    return _token.supportsInterface(type(IERC721Upgradeable).interfaceId);
  }

  function _isERC20(address _token) internal view returns (bool) {
    return _token.supportsInterface(type(IERC20Upgradeable).interfaceId);
  }

  function _stakeERC20(
    address _user,
    address _token,
    uint256 _amount
  ) internal virtual {
    IERC20Upgradeable(_token).safeTransferFrom(_user, address(this), _amount);

    accounts[_user].user = _user;
    accounts[_user].staked[_token] += _amount;

    _moveStakingPower(_user, address(this), _amount);

    emit StakedERC20(_user, _token, _amount, accounts[_user].staked[_token]);
  }

  function _stakeERC721(
    address _user,
    address _token,
    uint256 _tokenId
  ) internal virtual {
    require(accounts[_user].staked[_token] == 0, "Already staked ERC721");
    IERC721Upgradeable(_token).safeTransferFrom(_user, address(this), _tokenId);

    accounts[_user].user = _user;
    accounts[_user].staked[_token] = _tokenId;

    _moveStakingPower(_user, address(this), 1);

    emit StakedERC721(_user, _token, _tokenId, accounts[_user].staked[_token]);
  }

  function _unstakeERC20(
    address _user,
    address _token,
    uint256 _amount
  ) internal virtual {
    require(
      accounts[_user].staked[_token] >= _amount,
      "Should not exceed staked amount"
    );
    accounts[_user].staked[_token] -= _amount;

    _moveStakingPower(address(this), _user, _amount);

    IERC20Upgradeable(_token).safeTransfer(_user, _amount);

    emit UnstakedERC20(_user, _token, _amount, accounts[_user].staked[_token]);
  }

  function _unstakeERC721(
    address _user,
    address _token,
    uint256 _tokenId
  ) internal virtual {
    require(
      accounts[_user].staked[_token] == _tokenId,
      "Should be staked ERC721"
    );
    accounts[_user].staked[_token] -= _tokenId;

    _moveStakingPower(address(this), _user, 1);

    IERC721Upgradeable(_token).safeTransferFrom(address(this), _user, _tokenId);

    emit UnstakedERC721(
      _user,
      _token,
      _tokenId,
      accounts[_user].staked[_token]
    );
  }

  function _moveStakingPower(
    address _from,
    address _to,
    uint256 _amount
  ) internal {
    if (_from != _to && _amount > 0) {
      if (_from != address(this)) {
        _totalCheckpoints.push(_add, _amount);
        (uint256 oldValue, uint256 newValue) = _checkpoints[_from].push(
          _add,
          _amount
        );
        emit StakingPowerChanged(_from, oldValue, newValue);
      }

      if (_to != address(this)) {
        _totalCheckpoints.push(_subtract, _amount);
        (uint256 oldValue, uint256 newValue) = _checkpoints[_to].push(
          _subtract,
          _amount
        );
        emit StakingPowerChanged(_to, oldValue, newValue);
      }
    }
  }

  function _add(uint256 a, uint256 b) private pure returns (uint256) {
    return a + b;
  }

  function _subtract(uint256 a, uint256 b) private pure returns (uint256) {
    return a - b;
  }

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function totalStaked() external view returns (uint256) {
    return _totalCheckpoints.latest();
  }

  function pastTotalStaked(uint256 _blockNumber)
    external
    view
    returns (uint256)
  {
    require(_blockNumber < block.number, "Block not yet mined");
    return _totalCheckpoints.getAtBlock(_blockNumber);
  }

  function stakingPower(address _user) external view returns (uint256) {
    return _checkpoints[_user].latest();
  }

  function pastStakingPower(address _user, uint256 _blockNumber)
    external
    view
    returns (uint256)
  {
    return _checkpoints[_user].getAtBlock(_blockNumber);
  }

  function userStaked(address _user, address _token)
    external
    view
    returns (uint256)
  {
    return accounts[_user].staked[_token];
  }
}
