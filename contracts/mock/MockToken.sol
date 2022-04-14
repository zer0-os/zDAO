// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20, Ownable {
  constructor() ERC20("VToken", "VT") {}

  function mintFor(address _to, uint256 _amount) external onlyOwner {
    _mint(_to, _amount);
  }
}
