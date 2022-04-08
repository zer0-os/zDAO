// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library ZDAOLib {
  struct ZDAOInfo {
    uint256 id;
    address owner;
    string name;
    address gnosisSafe;
    IERC20 token;
    uint256 amount;
    bool destroyed;
  }
}
