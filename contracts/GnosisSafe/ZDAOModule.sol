// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {Module, Enum} from "@gnosis.pm/zodiac/contracts/core/Module.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IZDAOModule} from "../interfaces/IZDAOModule.sol";

contract ZDAOModule is IZDAOModule, Module, UUPSUpgradeable {
  // platform type => (proposalHash => Proposal)
  mapping(uint256 => mapping(uint256 => Proposal)) public proposals;

  /* -------------------------------------------------------------------------- */
  /*                                  Modifiers                                 */
  /* -------------------------------------------------------------------------- */

  modifier onlyAvatar() {
    require(msg.sender == avatar, "Only callable by GnosisSafe");
    _;
  }

  /* -------------------------------------------------------------------------- */
  /*                                 Initializer                                */
  /* -------------------------------------------------------------------------- */

  function __ZDAOModule_init(address _gnosisSafeProxy, address _organizer) public initializer {
    __Ownable_init();

    bytes memory initializeParams = abi.encode(_gnosisSafeProxy);
    setUp(initializeParams);
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  /**
   * @dev Initialize function, will be triggered when a new proxy is deployed
   * @param _initializeParams Parameters of initialization encoded
   */
  function setUp(bytes memory _initializeParams) public override initializer {
    __Ownable_init();
    address owner = abi.decode(_initializeParams, (address));

    setAvatar(owner);
    setTarget(owner);
  }

  function executeProposal(
    uint256 _platformType,
    uint256 _proposalHash,
    address _token,
    address _to,
    uint256 _amount
  ) external onlyAvatar {
    // check if proposal was already executed
    if (proposals[_platformType][_proposalHash].executed) {
      revert("Already executed");
    }

    bool success = _token == address(0)
      ? _executeForETH(_to, _amount)
      : _executeForERC20(_token, _to, _amount);
    if (success) {
      proposals[_platformType][_proposalHash] = Proposal({
        platformType: _platformType,
        proposalHash: _proposalHash,
        token: _token,
        to: _to,
        amount: _amount,
        executed: true
      });

      emit ProposalExecuted(_platformType, _proposalHash, _token, _to, _amount);
    }
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal Functions                             */
  /* -------------------------------------------------------------------------- */

  function _authorizeUpgrade(address _newImplementation) internal override onlyOwner {}

  function _executeForETH(address _to, uint256 _amount) internal returns (bool) {
    return exec(_to, _amount, new bytes(0), Enum.Operation.Call);
  }

  function _executeForERC20(
    address _token,
    address _to,
    uint256 _amount
  ) internal returns (bool) {
    return
      exec(
        _token,
        0,
        abi.encodeWithSignature("transfer(address,uint256)", _to, _amount),
        Enum.Operation.Call
      );
  }

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function isProposalExecuted(uint256 _platformType, uint256 _proposalHash)
    external
    view
    override
    returns (bool)
  {
    return proposals[_platformType][_proposalHash].executed;
  }
}
