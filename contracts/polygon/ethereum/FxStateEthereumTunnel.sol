// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {ZeroUpgradeable} from "../../abstracts/ZeroUpgradeable.sol";
import {IEthereumStateSender, IEthereumStateReceiver} from "../interfaces/ITunnel.sol";
import {FxBaseRootTunnel, ICheckpointManager, IFxStateSender} from "../tunnel/FxBaseRootTunnel.sol";

contract FxStateEthereumTunnel is
  ZeroUpgradeable,
  FxBaseRootTunnel,
  IEthereumStateSender
{
  /**
   * Address to EthereumZDAOChef contract which is responsible for processing
   * the messages from the Polygon network
   */
  IEthereumStateReceiver public ethereumStateReceiver;

  modifier onlyStateReceiver() {
    require(
      msg.sender == address(ethereumStateReceiver),
      "Only for state receiver"
    );
    _;
  }

  /* -------------------------------------------------------------------------- */
  /*                                 Initializer                                */
  /* -------------------------------------------------------------------------- */

  function __FxStateEthereumTunnel_init(
    address checkpointManager_,
    address fxRoot_
  ) public initializer {
    ZeroUpgradeable.__ZeroUpgradeable_init();

    checkpointManager = ICheckpointManager(checkpointManager_);
    fxRoot = IFxStateSender(fxRoot_);
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function setEthereumStateReceiver(
    IEthereumStateReceiver ethereumStateReceiver_
  ) external onlyOwner {
    ethereumStateReceiver = ethereumStateReceiver_;
  }

  function setPolygonStateTunnel(address polygonTunnel) external onlyOwner {
    fxChildTunnel = polygonTunnel;
  }

  /**
   * @notice Send message to Polygon
   * @dev Callable only by EthereumZDAOChef contract
   */
  function sendMessageToChild(bytes calldata message)
    external
    onlyStateReceiver
  {
    _sendMessageToChild(message);
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal Functions                             */
  /* -------------------------------------------------------------------------- */

  function _processMessageFromChild(bytes memory data) internal override {
    if (address(ethereumStateReceiver) != address(0)) {
      ethereumStateReceiver.processMessageFromChild(data);
    }
  }
}
