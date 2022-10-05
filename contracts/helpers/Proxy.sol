// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {ERC1967Proxy} from "../oz/proxy/ERC1967/ERC1967Proxy.sol";

function createProxy(address logic, bytes memory data)
  returns (address payable)
{
  return
    payable(
      address(
        new ERC1967Proxy{
          salt: keccak256(abi.encodePacked(block.number, data))
        }(logic, data)
      )
    );
}
