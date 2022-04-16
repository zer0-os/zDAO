// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "../abstracts/ZeroUpgradeable.sol";

contract Registry is ZeroUpgradeable {
  using AddressUpgradeable for address;

  mapping(address => address) public rootToChildToken;
  mapping(address => address) public childToRootToken;

  event MapToken(address _rootToken, address _childToken);

  /* -------------------------------------------------------------------------- */
  /*                                 Initializer                                */
  /* -------------------------------------------------------------------------- */

  function __Registry_init() public initializer {
    ZeroUpgradeable.initialize();
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function mapToken(address _rootToken, address _childToken)
    external
    onlyOwner
  {
    require(
      _rootToken != address(0) && _childToken != address(0),
      "Invalid token address"
    );
    require(
      _rootToken.isContract() && _childToken.isContract(),
      "Should be contract address"
    );

    rootToChildToken[_rootToken] = _childToken;
    rootToChildToken[_childToken] = _rootToken;

    emit MapToken(_rootToken, _childToken);
  }
}
