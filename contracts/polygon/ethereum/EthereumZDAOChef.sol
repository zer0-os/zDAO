// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {ZeroUpgradeable, IERC20Upgradeable} from "../../abstracts/ZeroUpgradeable.sol";
import {createProxy} from "../../helpers/Proxy.sol";
import {IZNSHub} from "../../interfaces/IZNSHub.sol";
import {IEthereumStateSender, IEthereumStateReceiver, ITunnel} from "../interfaces/ITunnel.sol";
import {IZDAOFactory} from "../../interfaces/IZDAOFactory.sol";
import {IEthereumZDAOChef} from "./interfaces/IEthereumZDAOChef.sol";
import {IEthereumZDAO} from "./interfaces/IEthereumZDAO.sol";

contract EthereumZDAOChef is
  ZeroUpgradeable,
  IEthereumStateReceiver,
  IEthereumZDAOChef,
  IZDAOFactory
{
  address public zDAORegistry;
  /**
   * Address to FxStateEthereumTunnel which is responsible for sending message
   * from Ethereum to Polygon
   */
  IEthereumStateSender public ethereumStateSender;
  address public zDAOBase;

  mapping(uint256 => IEthereumZDAO) public override zDAOs;

  /* -------------------------------------------------------------------------- */
  /*                                  Modifiers                                 */
  /* -------------------------------------------------------------------------- */

  modifier onlyRegistry() {
    require(msg.sender == zDAORegistry, "Not a registry");
    _;
  }

  modifier onlyValidZDAO(uint256 _zDAOId) {
    require(_zDAOId > 0 && !_isZDAODestroyed(_zDAOId), "Invalid zDAO");
    _;
  }

  /* -------------------------------------------------------------------------- */
  /*                                 Initializer                                */
  /* -------------------------------------------------------------------------- */

  function __ZDAOChef_init(
    address _zDAORegistry,
    IEthereumStateSender _ethereumStateSender,
    address _zDAOBase
  ) public initializer {
    ZeroUpgradeable.__ZeroUpgradeable_init();

    zDAORegistry = _zDAORegistry;
    ethereumStateSender = _ethereumStateSender;
    zDAOBase = _zDAOBase;
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function setZDAORegistry(address _zDAORgistry) external onlyOwner {
    zDAORegistry = _zDAORgistry;
  }

  function setZDAOBase(address _zDAOBase) external onlyOwner {
    zDAOBase = _zDAOBase;
  }

  /**
   * @notice Add new zDAO associating with given zNA.
   *     Create new EthereumZDAO contract and associate new zDAO with given zNA.
   *     Once create new zDAO, it should be synchronized to Polygon.
   *     Users can create proposal and cast a vote after zDAO synchronization.
   * @dev Only zNA owner can create zDAO
   * @param _zDAOId zDAO unique id
   * @param _zNA zNA unique Id
   * @param _gnosisSafe Address to Gnosis Safe
   * @param _options Abi encoded the structure of zDAO information
   */
  function addNewZDAO(
    uint256 _zDAOId,
    uint256 _zNA,
    address _gnosisSafe,
    bytes calldata _options
  ) external override onlyRegistry returns (address) {
    assert(address(zDAOs[_zDAOId]) == address(0));

    ZDAOConfig memory config = abi.decode(_options, (ZDAOConfig));

    IEthereumZDAO zDAO = IEthereumZDAO(
      createProxy(
        zDAOBase,
        abi.encodeWithSelector(
          IEthereumZDAO.__ZDAO_init.selector,
          address(this),
          _zDAOId,
          _gnosisSafe,
          msg.sender, // zDAO createdBy
          config
        )
      )
    );

    zDAOs[_zDAOId] = zDAO;

    // send zDAO info to L2
    ethereumStateSender.sendMessageToChild(
      abi.encode(
        uint256(MessageType.CreateZDAO),
        _zDAOId,
        config.duration,
        config.token
      )
    );

    return address(zDAO);
  }

  /**
   * @notice Remove zDAO by zDAOId.
   *     Removed state should be synchronized to Polygon, so that stop
   *     user voting
   * @dev Only zDAO owner can remove zDAO, and only for valid zDAO
   * @param _zDAOId zDAO unique id
   */
  function removeZDAO(uint256 _zDAOId) external override onlyRegistry {
    zDAOs[_zDAOId].setDestroyed(true);

    // send zDAO info to L2
    ethereumStateSender.sendMessageToChild(
      abi.encode(uint256(MessageType.DeleteZDAO), _zDAOId)
    );
  }

  function modifyZDAO(
    uint256 _zDAOId,
    address _gnosisSafe,
    bytes calldata _options
  ) external override onlyRegistry {
    (address token, uint256 amount) = abi.decode(_options, (address, uint256));

    zDAOs[_zDAOId].modifyZDAO(_gnosisSafe, token, amount);
    // send proposal info to L2
    ethereumStateSender.sendMessageToChild(
      abi.encode(uint256(ITunnel.MessageType.UpdateToken), _zDAOId, token)
    );
  }

  /**
   * @notice Create a proposal, check the comment of createProposal function
   *     in the EthereumZDAO contract.
   *     Once create a new proposal, it should be synchronized to Polygon.
   * @dev Only for valid zDAO
   * @param _zDAOId zDAO unique id
   * @param _ipfs IPFS which contains proposal information
   */
  function createProposal(uint256 _zDAOId, string calldata _ipfs)
    external
    override
    onlyValidZDAO(_zDAOId)
  {
    uint256 proposalId = zDAOs[_zDAOId].createProposal(
      msg.sender, // created by
      _ipfs
    );

    emit ProposalCreated(
      _zDAOId,
      proposalId,
      msg.sender,
      uint256(block.number)
    );

    // send proposal info to L2
    ethereumStateSender.sendMessageToChild(
      abi.encode(
        uint256(ITunnel.MessageType.CreateProposal),
        _zDAOId,
        proposalId
      )
    );
  }

  /**
   * @notice Cancel proposal, check the comment of cancelProposal function
   *     in the EthereumZDAO contract.
   * @dev Only for valid zDAO
   * @param _zDAOId zDAO unique id
   * @param _proposalId Proposal unique id
   */
  function cancelProposal(uint256 _zDAOId, uint256 _proposalId)
    external
    override
    onlyValidZDAO(_zDAOId)
  {
    zDAOs[_zDAOId].cancelProposal(msg.sender, _proposalId);

    emit ProposalCanceled(_zDAOId, _proposalId, msg.sender);

    ethereumStateSender.sendMessageToChild(
      abi.encode(
        uint256(ITunnel.MessageType.CancelProposal),
        _zDAOId,
        _proposalId
      )
    );
  }

  /**
   * @notice Execute proposal, check the comment of executeProposal function
   *     in the EthereumZDAO contract.
   * @dev Only for valid zDAO
   * @param _zDAOId zDAO unique id
   * @param _proposalId Proposal unique id
   */
  function executeProposal(uint256 _zDAOId, uint256 _proposalId)
    external
    override
    onlyValidZDAO(_zDAOId)
  {
    zDAOs[_zDAOId].executeProposal(msg.sender, _proposalId);

    emit ProposalExecuted(_zDAOId, _proposalId, msg.sender);
  }

  /**
   * @notice Process message from the Polygon network
   *     The message is encoded by certain format according to protocol type
   * @dev Callable by root state sender
   */
  function processMessageFromChild(bytes calldata _message) external override {
    require(msg.sender == address(ethereumStateSender), "Not a state sender");
    _processMessageFromChild(_message);
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal Functions                             */
  /* -------------------------------------------------------------------------- */

  function _processMessageFromChild(bytes memory _message) internal {
    uint256 messageType = abi.decode(_message, (uint256));
    if (messageType == uint256(ITunnel.MessageType.CalculateProposal)) {
      _calculateProposal(_message);
    }
  }

  function _calculateProposal(bytes memory _message) internal virtual {
    (
      uint256 messageType2,
      uint256 zDAOId,
      uint256 proposalId,
      uint256 voters,
      uint256 yes,
      uint256 no
    ) = abi.decode(
        _message,
        (uint256, uint256, uint256, uint256, uint256, uint256)
      );
    require(zDAOId > 0 && !_isZDAODestroyed(zDAOId), "Invalid zDAO");

    // let zDAO decode
    zDAOs[zDAOId].calculateProposal(proposalId, voters, yes, no);

    emit ProposalCalculated(zDAOId, proposalId, voters, yes, no);
  }

  function _isZDAODestroyed(uint256 _index) internal view returns (bool) {
    return zDAOs[_index].destroyed();
  }

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function zDAOInfo(uint256 _zDAOId)
    external
    view
    returns (IEthereumZDAO.ZDAOInfo memory)
  {
    return zDAOs[_zDAOId].zDAOInfo();
  }
}
