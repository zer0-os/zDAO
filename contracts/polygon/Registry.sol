// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {ZeroUpgradeable} from "../abstracts/ZeroUpgradeable.sol";

contract Registry is ZeroUpgradeable {
  mapping(address => address) public rootToChildToken;
  mapping(address => address) public childToRootToken;
  address[] public rootTokens;
  address[] public childTokens;

  event MapToken(address _rootToken, address _childToken);

  /* -------------------------------------------------------------------------- */
  /*                                 Initializer                                */
  /* -------------------------------------------------------------------------- */

  function __Registry_init() public initializer {
    ZeroUpgradeable.__ZeroUpgradeable_init();
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

    rootToChildToken[_rootToken] = _childToken;
    childToRootToken[_childToken] = _rootToken;
    rootTokens.push(_rootToken);
    childTokens.push(_childToken);

    emit MapToken(_rootToken, _childToken);
  }

  function listRootTokens(uint256 _startIndex, uint256 _count)
    external
    view
    returns (address[] memory records)
  {
    uint256 numRecords = _count;
    if (numRecords > (rootTokens.length - _startIndex)) {
      numRecords = rootTokens.length - _startIndex;
    }

    records = new address[](numRecords);

    for (uint256 i = 0; i < numRecords; ++i) {
      records[i] = rootTokens[_startIndex + i];
    }

    return records;
  }

  function listChildTokens(uint256 _startIndex, uint256 _count)
    external
    view
    returns (address[] memory records)
  {
    uint256 numRecords = _count;
    if (numRecords > (childTokens.length - _startIndex)) {
      numRecords = childTokens.length - _startIndex;
    }

    records = new address[](numRecords);

    for (uint256 i = 0; i < numRecords; ++i) {
      records[i] = childTokens[_startIndex + i];
    }

    return records;
  }
}
