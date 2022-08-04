// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {Module, Enum} from "@gnosis.pm/zodiac/contracts/core/Module.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IZDAOModule} from "../interfaces/IZDAOModule.sol";

contract ZDAOModule is IZDAOModule, Module, AccessControlUpgradeable, UUPSUpgradeable {
  mapping(uint256 => Proposal) public proposals;

  /* -------------------------------------------------------------------------- */
  /*                                 Initializer                                */
  /* -------------------------------------------------------------------------- */

  function __ZDAOModule_init(address _owner) public initializer {
    __Ownable_init();

    bytes memory initializeParams = abi.encode(_owner);
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
    transferOwnership(owner);
  }

  function executeProposal(
    uint256 _platformType,
    string calldata _proposalId,
    address _token,
    address _to,
    uint256 _amount
  ) external {
    bool success = _token == address(0)
      ? _executeForETH(_to, _amount)
      : _executeForERC20(_token, _to, _amount);
    if (success) {
      uint256 index = _proposalIndex(_platformType, _proposalId);
      proposals[index] = Proposal({
        platformType: _platformType,
        proposalId: _proposalId,
        token: _token,
        to: _to,
        amount: _amount,
        executed: true
      });
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

  function _proposalIndex(uint256 _platformType, string memory _proposalId)
    internal
    pure
    returns (uint256)
  {
    return uint256(keccak256(abi.encodePacked(_platformType, _proposalId)));
  }

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function isProposalExecuted(uint256 _platformType, string calldata _proposalId)
    external
    view
    returns (bool)
  {
    uint256 index = _proposalIndex(_platformType, _proposalId);
    return proposals[index].executed;
  }
}
