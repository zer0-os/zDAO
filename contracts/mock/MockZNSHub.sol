// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {Ownable} from "../oz/access/Ownable.sol";
import {IZNSHub} from "../interfaces/IZNSHub.sol";

contract MockZNSHub is Ownable, IZNSHub {
  mapping(uint256 => address) public zNAtoOwner;

  function addZNAOwner(uint256 _domainId, address _owner) external onlyOwner {
    zNAtoOwner[_domainId] = _owner;
  }

  function ownerOf(uint256 domainId) external view returns (address) {
    return zNAtoOwner[domainId];
  }
}
