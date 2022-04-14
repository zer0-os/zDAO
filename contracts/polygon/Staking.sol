// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "../abstracts/ZeroUpgradeable.sol";
import "./interfaces/IStaking.sol";
import "./interfaces/ILockable.sol";

contract Staking is ZeroUpgradeable, IStaking, ILockable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  bytes32 public constant LOCKER_ROLE = keccak256("LOCKER_ROLE");

  struct Account {
    address user;
    // <IERC20, token amount>
    mapping(address => uint256) staked;
  }

  struct Lockable {
    uint256 staked;
    uint256 lockedRepeat;
  }

  // <user addres, <IERC20, Account>>
  mapping(address => Account) public accounts;

  // <IERC20, Lockable>
  mapping(address => Lockable) public lockable;

  /* -------------------------------------------------------------------------- */
  /*                                  Modifiers                                 */
  /* -------------------------------------------------------------------------- */

  modifier isLocker() {
    require(hasRole(LOCKER_ROLE, msg.sender), "Should have locker role");
    _;
  }

  modifier isUnlocked(address _token) {
    require(lockable[_token].lockedRepeat < 1, "Should be unlocked");
    _;
  }

  /* -------------------------------------------------------------------------- */
  /*                                 Initializer                                */
  /* -------------------------------------------------------------------------- */

  function __Staking_init() public initializer {
    ZeroUpgradeable.initialize();
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function stake(address _token, uint256 _amount) external {
    _stake(msg.sender, _token, _amount);
  }

  function unstake(address _token, uint256 _amount)
    external
    isUnlocked(_token)
  {
    _unstake(msg.sender, _token, _amount);
  }

  function lock(address _token) external isLocker {
    _lock(_token);
  }

  function unlock(address _token) external isLocker {
    _unlock(_token);
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal Functions                             */
  /* -------------------------------------------------------------------------- */

  function _stake(
    address _user,
    address _token,
    uint256 _amount
  ) internal virtual {
    IERC20Upgradeable(_token).safeTransferFrom(_user, address(this), _amount);

    accounts[_user].user = _user;
    accounts[_user].staked[_token] += _amount;
    lockable[_token].staked += _amount;

    emit Staked(_user, _token, _amount, accounts[_user].staked[_token]);
  }

  function _unstake(
    address _user,
    address _token,
    uint256 _amount
  ) internal virtual {
    require(
      accounts[_user].staked[_token] >= _amount,
      "Should not exceed staked amount"
    );
    accounts[_user].staked[_token] -= _amount;
    lockable[_token].staked -= _amount;

    IERC20Upgradeable(_token).safeTransfer(_user, _amount);

    emit Unstaked(_user, _token, _amount, accounts[_user].staked[_token]);
  }

  function _lock(address _token) internal virtual {
    lockable[_token].lockedRepeat++;

    emit Locked(_token, lockable[_token].staked, lockable[_token].lockedRepeat);
  }

  function _unlock(address _token) internal virtual {
    require(lockable[_token].lockedRepeat > 0, "Already unlocked");

    lockable[_token].lockedRepeat--;

    emit Unlocked(
      _token,
      lockable[_token].staked,
      lockable[_token].lockedRepeat
    );
  }

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function totalStaked(address _token) external view returns (uint256) {
    return lockable[_token].staked;
  }

  function userStaked(address _user, address _token)
    external
    view
    returns (uint256)
  {
    return accounts[_user].staked[_token];
  }

  function locked(address _token) external view returns (uint256) {
    return lockable[_token].lockedRepeat;
  }
}
