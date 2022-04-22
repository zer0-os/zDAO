// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import {ERC721HolderUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import {ERC165CheckerUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165CheckerUpgradeable.sol";
import {ZeroUpgradeable, SafeERC20Upgradeable, IERC20Upgradeable} from "../abstracts/ZeroUpgradeable.sol";
import {IStaking} from "./interfaces/IStaking.sol";
import {ILockable} from "./interfaces/ILockable.sol";

contract Staking is
  ZeroUpgradeable,
  IStaking,
  ILockable,
  ERC721HolderUpgradeable
{
  using SafeERC20Upgradeable for IERC20Upgradeable;
  using ERC165CheckerUpgradeable for address;

  bytes32 public constant LOCKER_ROLE = keccak256("LOCKER_ROLE");

  struct Account {
    address user;
    // <IERC20, token amount>
    // <IERC721, token id>
    mapping(address => uint256) staked;
  }

  struct Lockable {
    uint256 staked;
    uint256 lockedRepeat;
  }

  // <user addres, <IERC20, Account>>
  // <user addres, <IERC721, Account>>
  mapping(address => Account) public accounts;

  // <IERC20, Lockable>
  // <IERC721, Lockable>
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
    ZeroUpgradeable.__ZeroUpgradeable_init();
    __ERC721Holder_init();
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
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

  function unstakeERC20(address _token, uint256 _amount)
    external
    isUnlocked(_token)
  {
    _unstakeERC20(msg.sender, _token, _amount);
  }

  function unstakeERC721(address _token, uint256 _tokenId)
    external
    isUnlocked(_token)
  {
    _unstakeERC721(msg.sender, _token, _tokenId);
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
    lockable[_token].staked += _amount;

    emit StakedERC20(_user, _token, _amount, accounts[_user].staked[_token]);
  }

  function _stakeERC721(
    address _user,
    address _token,
    uint256 _tokenId
  ) internal virtual {
    IERC721Upgradeable(_token).safeTransferFrom(_user, address(this), _tokenId);

    accounts[_user].user = _user;
    accounts[_user].staked[_token] = _tokenId;
    lockable[_token].staked += 1;

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
    lockable[_token].staked -= _amount;

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
    lockable[_token].staked -= 1;

    IERC721Upgradeable(_token).safeTransferFrom(address(this), _user, _tokenId);

    emit UnstakedERC721(
      _user,
      _token,
      _tokenId,
      accounts[_user].staked[_token]
    );
  }

  function _lock(address _token) internal virtual {
    lockable[_token].lockedRepeat++;

    emit Locked(_token, lockable[_token].staked, lockable[_token].lockedRepeat);
  }

  function _unlock(address _token) internal virtual {
    // require(lockable[_token].lockedRepeat > 0, "Already unlocked");
    // lockable[_token].lockedRepeat--;

    if (lockable[_token].lockedRepeat < 1) {
      // already unlocked
      return;
    }

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
