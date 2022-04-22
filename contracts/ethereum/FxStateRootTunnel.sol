// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {ZeroUpgradeable} from "../abstracts/ZeroUpgradeable.sol";
import {IRootStateSender, IRootStateReceiver} from "../interfaces/ITunnel.sol";
import {FxBaseRootTunnel, ICheckpointManager, IFxStateSender} from "../tunnel/FxBaseRootTunnel.sol";

contract FxStateRootTunnel is
  ZeroUpgradeable,
  FxBaseRootTunnel,
  IRootStateSender
{
  IRootStateReceiver public rootStateReceiver;

  /* -------------------------------------------------------------------------- */
  /*                                 Initializer                                */
  /* -------------------------------------------------------------------------- */

  function __FxStateRootTunnel_init(address _checkpointManager, address _fxRoot)
    public
    initializer
  {
    ZeroUpgradeable.__ZeroUpgradeable_init();

    checkpointManager = ICheckpointManager(_checkpointManager);
    fxRoot = IFxStateSender(_fxRoot);
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function setRootStateReceiver(IRootStateReceiver _rootStateReceiver)
    external
    onlyOwner
  {
    rootStateReceiver = _rootStateReceiver;
  }

  function setFxChildTunnel(address _fxChildTunnel) external onlyOwner {
    fxChildTunnel = _fxChildTunnel;
  }

  function sendMessageToChild(bytes calldata message) external {
    _sendMessageToChild(message);
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal Functions                             */
  /* -------------------------------------------------------------------------- */

  function _processMessageFromChild(bytes memory _data) internal override {
    if (address(rootStateReceiver) != address(0)) {
      rootStateReceiver.processMessageFromChild(_data);
    }
  }
}
