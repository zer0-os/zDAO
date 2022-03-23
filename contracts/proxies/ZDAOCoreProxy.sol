// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract ZDAOCoreProxy is TransparentUpgradeableProxy {
  constructor(address _logic, address _proxyAdmin)
    TransparentUpgradeableProxy(_logic, _proxyAdmin, "")
  {}
}
