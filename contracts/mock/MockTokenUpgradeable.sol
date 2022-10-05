// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {OwnableUpgradeable} from "../oz-upgradeable/access/OwnableUpgradeable.sol";
import {ERC20Upgradeable} from "../oz-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {UUPSUpgradeable} from "../oz-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract MockTokenUpgradeable is
  OwnableUpgradeable,
  ERC20Upgradeable,
  UUPSUpgradeable
{
  function __MockTokenUpgradeable_init(
    string memory name,
    string memory symbol
  ) public initializer {
    __Ownable_init();
    __ERC20_init(_name, _symbol);
    __UUPSUpgradeable_init();
  }

  function _authorizeUpgrade(address newImplementation)
    internal
    override
    onlyOwner
  {}

  function mintFor(address to, uint256 amount) external onlyOwner {
    _mint(to, amount);
  }
}
