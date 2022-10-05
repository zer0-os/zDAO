// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {ERC20Upgradeable} from "../../oz-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {IERC721Upgradeable} from "../../oz-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import {ERC721HolderUpgradeable} from "../../oz-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import {ERC165CheckerUpgradeable} from "../../oz-upgradeable/utils/introspection/ERC165CheckerUpgradeable.sol";
import "../../oz-upgradeable/utils/Checkpoints.sol";
import {ZeroUpgradeable, SafeERC20Upgradeable, IERC20Upgradeable} from "../../abstracts/ZeroUpgradeable.sol";
import {IStaking} from "./interfaces/IStaking.sol";

contract Staking is ZeroUpgradeable, IStaking, ERC721HolderUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;
  using ERC165CheckerUpgradeable for address;
  using Checkpoints for Checkpoints.History;

  // <user address, <token, Checkpoints.History>>
  mapping(address => mapping(address => Checkpoints.History))
    private _checkpoints;
  // maping<user address, mapping<token, mapping<token id, boolean>>>
  mapping(address => mapping(address => mapping(uint256 => bool)))
    private _erc721Staked;
  // mapping<token, decimals>
  mapping(address => uint256) private _decimals;

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

  /**
   * @notice Stake ERC20 token, the staking contract save the checkpoint which
   *     contains snapshot of block number and accumulated staked amount.
   * @param token Address to ERC20 token
   * @param amount Token amount to stake
   */
  function stakeERC20(address token, uint256 amount) external {
    _stakeERC20(msg.sender, token, amount);
  }

  /**
   * @notice Stake ERC721 token, as same as stakeERC20, this stores checkpoints
   * @param token Address to ERC721 token
   * @param tokenId Token Id
   */
  function stakeERC721(address token, uint256 tokenId) external {
    require(_isERC721(token), "Should ERC721 token address");
    _stakeERC721(msg.sender, token, tokenId);
  }

  /**
   * @notice Unstake ERC20 token, as same as stakeERC20, this stores
   *     checkpoints with accumulated token amount.
   * @param token Address to ERC20 token
   * @param amount Token amount to unstake
   */
  function unstakeERC20(address token, uint256 amount) external {
    _unstakeERC20(msg.sender, token, amount);
  }

  /**
   * @notice Unstake ERC721 token, as same as stakeERC20, this stores
   *     checkpoints with accumulated token amount.
   * @param token Address to ERC721 token
   * @param tokenId Token id
   */
  function unstakeERC721(address token, uint256 tokenId) external {
    require(_isERC721(token), "Should ERC721 token address");
    _unstakeERC721(msg.sender, token, tokenId);
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal Functions                             */
  /* -------------------------------------------------------------------------- */

  function _isERC721(address token) internal view returns (bool) {
    return token.supportsInterface(type(IERC721Upgradeable).interfaceId);
  }

  function _isERC20(address token) internal view returns (bool) {
    return token.supportsInterface(type(IERC20Upgradeable).interfaceId);
  }

  function _stakeERC20(
    address user,
    address token,
    uint256 amount
  ) internal virtual {
    uint256 decimals = ERC20Upgradeable(token).decimals();
    _decimals[token] = decimals;

    IERC20Upgradeable(token).safeTransferFrom(user, address(this), amount);

    _moveStakingPower(user, address(this), token, amount);

    emit StakedERC20(user, token, decimals, amount);
  }

  function _stakeERC721(
    address user,
    address token,
    uint256 tokenId
  ) internal virtual {
    _decimals[token] = 0;
    IERC721Upgradeable(token).safeTransferFrom(user, address(this), tokenId);

    _moveStakingPower(user, address(this), token, 1);
    _erc721Staked[user][token][tokenId] = true;

    emit StakedERC721(user, token, tokenId);
  }

  function _unstakeERC20(
    address user,
    address token,
    uint256 amount
  ) internal virtual {
    require(
      ERC20Upgradeable(token).decimals() == _decimals[token],
      "Should ERC20 token address"
    );
    require(
      _checkpoints[user][token].latest() >= amount,
      "Should not exceed staked amount"
    );

    _moveStakingPower(address(this), user, token, amount);

    IERC20Upgradeable(token).safeTransfer(user, amount);

    emit UnstakedERC20(user, token, _decimals[token], amount);
  }

  function _unstakeERC721(
    address user,
    address token,
    uint256 tokenId
  ) internal virtual {
    require(_erc721Staked[user][token][tokenId], "Should be staked ERC721");

    _moveStakingPower(address(this), user, token, 1);
    _erc721Staked[user][token][tokenId] = false;

    IERC721Upgradeable(token).safeTransferFrom(address(this), user, tokenId);

    emit UnstakedERC721(user, token, tokenId);
  }

  function _moveStakingPower(
    address from,
    address to,
    address token,
    uint256 amount
  ) internal {
    if (from != to && amount > 0) {
      if (from != address(this)) {
        (uint256 oldValue, uint256 newValue) = _checkpoints[from][token].push(
          _add,
          amount
        );
        emit StakingPowerChanged(from, token, oldValue, newValue);
      }

      if (to != address(this)) {
        (uint256 oldValue, uint256 newValue) = _checkpoints[to][token].push(
          _subtract,
          amount
        );
        emit StakingPowerChanged(to, token, oldValue, newValue);
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

  /**
   * @notice Get accumulated staking power at current block number
   * @param user User address
   * @param token Address to staked token(ERC20 or ERC721)
   */
  function stakingPower(address user, address token)
    external
    view
    returns (uint256)
  {
    return _checkpoints[user][token].latest();
  }

  /**
   * @notice Get accumulated staking power at given block number
   * @param user User address
   * @param token Address to staked token(ERC20 or ERC721)
   * @param blockNumber Block number
   */
  function pastStakingPower(
    address user,
    address token,
    uint256 blockNumber
  ) external view returns (uint256) {
    return _checkpoints[user][token].getAtBlock(blockNumber);
  }

  function stakedERC20Amount(address user, address token)
    external
    view
    override
    returns (uint256)
  {
    return _checkpoints[user][token].latest();
  }

  function isStakedERC721(
    address user,
    address token,
    uint256 tokenId
  ) external view override returns (bool) {
    return _erc721Staked[user][token][tokenId];
  }
}
