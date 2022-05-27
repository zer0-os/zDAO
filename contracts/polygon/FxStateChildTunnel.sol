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
  /**
   * Address to PolyZDAOChef contract which is responsible for processing
   * the messages from the Ethereum network
   */
  IChildStateReceiver public childStateReceiver;

  modifier onlyStateReceiver() {
    require(
      msg.sender == address(childStateReceiver),
      "Only for state receiver"
    );
    _;
  }

  /* -------------------------------------------------------------------------- */
  /*                                 Initializer                                */
  /* -------------------------------------------------------------------------- */

  function __FxStateChildTunnel_init(address _fxChild) public initializer {
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

  /**
   * @notice Send message to Ethereum
   * @dev Callable only by PolyZDAOChef contract
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
    if (address(childStateReceiver) != address(0)) {
      childStateReceiver.processMessageFromRoot(message);
    }
  }
}
