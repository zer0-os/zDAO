// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

contract MockCollectibleUpgradeable is OwnableUpgradeable, ERC721Upgradeable {
  function __MockCollectibleUpgradeable_init(
    string memory _name,
    string memory _symbol
  ) public initializer {
    __Ownable_init();
    __ERC721_init(_name, _symbol);
  }

  function mintFor(address _to, uint256 _tokenId) external onlyOwner {
    _mint(_to, _tokenId);
  }
}
