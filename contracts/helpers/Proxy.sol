// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

function createProxy(address _logic, bytes memory _data)
  returns (address payable)
{
  return payable(address(new ERC1967Proxy(_logic, _data)));
}
