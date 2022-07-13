// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {ZeroUpgradeable} from "../../abstracts/ZeroUpgradeable.sol";
import {IPolygonStateSender, IPolygonStateReceiver} from "../interfaces/ITunnel.sol";
import {FxBaseChildTunnel} from "../tunnel/FxBaseChildTunnel.sol";

contract FxStatePolygonTunnel is
  ZeroUpgradeable,
  FxBaseChildTunnel,
  IPolygonStateSender
{
  /**
   * Address to PolygonZDAOChef contract which is responsible for processing
   * the messages from the Ethereum network
   */
  IPolygonStateReceiver public polygonStateReceiver;

  modifier onlyStateReceiver() {
    require(
      msg.sender == address(polygonStateReceiver),
      "Only for state receiver"
    );
    _;
  }

  /* -------------------------------------------------------------------------- */
  /*                                 Initializer                                */
  /* -------------------------------------------------------------------------- */

  function __FxStatePolygonTunnel_init(address _fxChild) public initializer {
    ZeroUpgradeable.__ZeroUpgradeable_init();

    fxChild = _fxChild;
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function setPolygonStateReceiver(IPolygonStateReceiver _polygonStateReceiver)
    external
    onlyOwner
  {
    polygonStateReceiver = _polygonStateReceiver;
  }

  function setEthereumStateTunnel(address _ethereumTunnel) external onlyOwner {
    fxRootTunnel = _ethereumTunnel;
  }

  /**
   * @notice Send message to Ethereum
   * @dev Callable only by PolygonZDAOChef contract
   */
  function sendMessageToRoot(bytes calldata message)
    external
    onlyStateReceiver
  {
    _sendMessageToRoot(message);
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal Functions                             */
  /* -------------------------------------------------------------------------- */

  function _processMessageFromRoot(
    uint256,
    address sender,
    bytes memory message
  ) internal override validateSender(sender) {
    if (address(polygonStateReceiver) != address(0)) {
      polygonStateReceiver.processMessageFromRoot(message);
    }
  }
}
