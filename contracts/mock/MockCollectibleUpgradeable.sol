// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {OwnableUpgradeable} from "../oz-upgradeable/access/OwnableUpgradeable.sol";
import {ERC721Upgradeable} from "../oz-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {UUPSUpgradeable} from "../oz-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract MockCollectibleUpgradeable is
  OwnableUpgradeable,
  ERC721Upgradeable,
  UUPSUpgradeable
{
  function __MockCollectibleUpgradeable_init(
    string memory _name,
    string memory _symbol
  ) public initializer {
    __Ownable_init();
    __ERC721_init(_name, _symbol);
    __UUPSUpgradeable_init();
  }

  function _authorizeUpgrade(address newImplementation)
    internal
    override
    onlyOwner
  {}

  function mintFor(address _to, uint256 _tokenId) external onlyOwner {
    _mint(_to, _tokenId);
  }
}
