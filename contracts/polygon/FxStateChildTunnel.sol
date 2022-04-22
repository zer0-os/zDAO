// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {ZeroUpgradeable} from "../abstracts/ZeroUpgradeable.sol";
import {IChildStateSender, IChildStateReceiver} from "../interfaces/ITunnel.sol";
import {FxBaseChildTunnel} from "../tunnel/FxBaseChildTunnel.sol";

contract FxStateChildTunnel is
  ZeroUpgradeable,
  FxBaseChildTunnel,
  IChildStateSender
{
  IChildStateReceiver public childStateReceiver;

  /* -------------------------------------------------------------------------- */
  /*                                 Initializer                                */
  /* -------------------------------------------------------------------------- */

  function __ZDAOChef_init(address _fxChild) public initializer {
    ZeroUpgradeable.__ZeroUpgradeable_init();

    fxChild = _fxChild;
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function setChildStateReceiver(IChildStateReceiver _childStateReceiver)
    external
    onlyOwner
  {
    childStateReceiver = _childStateReceiver;
  }

  function setFxRootTunnel(address _fxRootTunnel) external onlyOwner {
    fxRootTunnel = _fxRootTunnel;
  }

  function sendMessageToRoot(bytes calldata message) external {
    _sendMessageToRoot(message);
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal Functions                             */
  /* -------------------------------------------------------------------------- */

  function _processMessageFromRoot(
    uint256,
    address,
    bytes memory message
  ) internal override {
    if (address(childStateReceiver) != address(0)) {
      childStateReceiver.processMessageFromRoot(message);
    }
  }
}
