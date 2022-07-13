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
    address _checkpointManager,
    address _fxRoot
  ) public initializer {
    ZeroUpgradeable.__ZeroUpgradeable_init();

    checkpointManager = ICheckpointManager(_checkpointManager);
    fxRoot = IFxStateSender(_fxRoot);
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function setEthereumStateReceiver(
    IEthereumStateReceiver _ethereumStateReceiver
  ) external onlyOwner {
    ethereumStateReceiver = _ethereumStateReceiver;
  }

  function setPolygonStateTunnel(address _polygonTunnel) external onlyOwner {
    fxChildTunnel = _polygonTunnel;
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

  function _processMessageFromChild(bytes memory _data) internal override {
    if (address(ethereumStateReceiver) != address(0)) {
      ethereumStateReceiver.processMessageFromChild(_data);
    }
  }
}
