// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "../interfaces/IZNSHub.sol";

contract ZNSHubTest is IZNSHub {
  mapping(uint256 => address) owners;

  function ownerOf(uint256 domainId) external view returns (address) {
    return owners[domainId];
  }

  function setOwnerOf(uint256 domainId, address newOwner) external {
    owners[domainId] = newOwner;
  }
}
