// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract MockTokenUpgradeable is OwnableUpgradeable, ERC20Upgradeable {
  function __MockTokenUpgradeable_init(
    string memory _name,
    string memory _symbol
  ) public initializer {
    __Ownable_init();
    __ERC20_init(_name, _symbol);
  }

  function mintFor(address _to, uint256 _amount) external onlyOwner {
    _mint(_to, _amount);
  }
}
