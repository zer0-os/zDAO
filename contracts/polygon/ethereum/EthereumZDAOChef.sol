// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {ZeroUpgradeable, IERC20Upgradeable} from "../../abstracts/ZeroUpgradeable.sol";
import {createProxy} from "../../helpers/Proxy.sol";
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

  mapping(uint256 => IEthereumZDAO) public zDAOs;

  /* -------------------------------------------------------------------------- */
  /*                                  Modifiers                                 */
  /* -------------------------------------------------------------------------- */

  modifier onlyRegistry() {
    require(msg.sender == zDAORegistry, "Not a registry");
    _;
  }

  modifier onlyValidZDAO(uint256 zDAOId) {
    require(zDAOId > 0 && !_isZDAODestroyed(zDAOId), "Invalid zDAO");
    _;
  }

  /* -------------------------------------------------------------------------- */
  /*                                 Initializer                                */
  /* -------------------------------------------------------------------------- */

  function __ZDAOChef_init(
    address zDAORegistry_,
    IEthereumStateSender ethereumStateSender_,
    address zDAOBase_
  ) public initializer {
    ZeroUpgradeable.__ZeroUpgradeable_init();

    zDAORegistry = zDAORegistry_;
    ethereumStateSender = ethereumStateSender_;
    zDAOBase = zDAOBase_;
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function setZDAORegistry(address zDAORgistry_) external override onlyOwner {
    zDAORegistry = zDAORgistry_;
  }

  function setZDAOBase(address zDAOBase_) external override onlyOwner {
    zDAOBase = zDAOBase_;
  }

  /**
   * @notice Add new zDAO with given parameters.
   *     Create new EthereumZDAO contract and associate new zDAO.
   *     Once create new zDAO, it should be synchronized to Polygon.
   *     Users can create proposal and cast a vote after zDAO synchronization.
   * @dev Only callable by registry contract
   * @param zDAOId zDAO unique id
   * @param gnosisSafe Address to Gnosis Safe
   * @param options Abi encoded the structure of zDAO information
   */
  function addNewZDAO(
    uint256 zDAOId,
    address createdBy,
    address gnosisSafe,
    bytes calldata options
  ) external override onlyRegistry returns (address) {
    assert(address(zDAOs[zDAOId]) == address(0));

    ZDAOConfig memory config = abi.decode(options, (ZDAOConfig));
    require(config.token != address(0), "Invalid voting token");
    require(config.duration > 0, "Invalid voting period");
    require(config.votingThreshold > 0, "Invalid voting threshold");

    IEthereumZDAO zDAO = IEthereumZDAO(
      createProxy(
        zDAOBase,
        abi.encodeWithSelector(
          IEthereumZDAO.__ZDAO_init.selector,
          address(this),
          zDAOId,
          createdBy,
          gnosisSafe,
          config
        )
      )
    );

    zDAOs[zDAOId] = zDAO;

    emit DAOCreated(
      zDAOId,
      address(zDAO),
      createdBy,
      gnosisSafe,
      config.token,
      config.amount,
      config.duration,
      config.votingDelay,
      config.votingThreshold,
      config.minimumVotingParticipants,
      config.minimumTotalVotingTokens,
      config.isRelativeMajority
    );

    // send zDAO info to L2
    ethereumStateSender.sendMessageToChild(
      abi.encode(
        uint256(MessageType.CreateZDAO),
        zDAOId,
        config.duration,
        config.votingDelay,
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
   * @param zDAOId zDAO unique id
   */
  function removeZDAO(uint256 zDAOId) external override onlyRegistry {
    zDAOs[zDAOId].setDestroyed(true);

    // send zDAO info to L2
    ethereumStateSender.sendMessageToChild(
      abi.encode(uint256(MessageType.DeleteZDAO), zDAOId)
    );
  }

  function modifyZDAO(
    uint256 zDAOId,
    address gnosisSafe,
    bytes calldata options
  ) external override onlyRegistry {
    (address token, uint256 amount) = abi.decode(options, (address, uint256));

    zDAOs[zDAOId].modifyZDAO(gnosisSafe, token, amount);
    // send proposal info to L2
    ethereumStateSender.sendMessageToChild(
      abi.encode(uint256(ITunnel.MessageType.UpdateToken), zDAOId, token)
    );
  }

  /**
   * @notice Create a proposal, check the comment of createProposal function
   *     in the EthereumZDAO contract.
   *     Once create a new proposal, it should be synchronized to Polygon.
   * @dev Only for valid zDAO
   * @param zDAOId zDAO unique id
   * @param choices Array of choices
   * @param ipfs IPFS which contains proposal information
   */
  function createProposal(
    uint256 zDAOId,
    string[] calldata choices,
    string calldata ipfs
  ) external override onlyValidZDAO(zDAOId) {
    require(choices.length > 0, "Should have at least one choice");

    uint256 proposalId = zDAOs[zDAOId].createProposal(
      msg.sender, // created by
      choices,
      ipfs
    );

    emit ProposalCreated(
      zDAOId,
      proposalId,
      choices.length,
      msg.sender,
      uint256(block.number),
      ipfs
    );

    // send proposal info to L2
    ethereumStateSender.sendMessageToChild(
      abi.encode(
        uint256(ITunnel.MessageType.CreateProposal),
        zDAOId,
        proposalId,
        choices.length,
        block.timestamp
      )
    );
  }

  /**
   * @notice Cancel proposal, check the comment of cancelProposal function
   *     in the EthereumZDAO contract.
   * @dev Only for valid zDAO
   * @param zDAOId zDAO unique id
   * @param proposalId Proposal unique id
   */
  function cancelProposal(uint256 zDAOId, uint256 proposalId)
    external
    override
    onlyValidZDAO(zDAOId)
  {
    zDAOs[zDAOId].cancelProposal(msg.sender, proposalId);

    emit ProposalCanceled(zDAOId, proposalId, msg.sender);

    ethereumStateSender.sendMessageToChild(
      abi.encode(
        uint256(ITunnel.MessageType.CancelProposal),
        zDAOId,
        proposalId
      )
    );
  }

  /**
   * @notice Process message from the Polygon network
   *     The message is encoded by certain format according to protocol type
   * @dev Callable by root state sender
   */
  function processMessageFromChild(bytes calldata message) external override {
    require(msg.sender == address(ethereumStateSender), "Not a state sender");
    _processMessageFromChild(message);
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal Functions                             */
  /* -------------------------------------------------------------------------- */

  function _processMessageFromChild(bytes memory message) internal {
    uint256 messageType = abi.decode(message, (uint256));
    if (messageType == uint256(ITunnel.MessageType.CalculateProposal)) {
      _calculateProposal(message);
    }
  }

  function _calculateProposal(bytes memory message) internal virtual {
    (
      uint256 messageType2,
      uint256 zDAOId,
      uint256 proposalId,
      uint256 voters,
      uint256[] memory votes
    ) = abi.decode(message, (uint256, uint256, uint256, uint256, uint256[]));
    require(zDAOId > 0 && !_isZDAODestroyed(zDAOId), "Invalid zDAO");

    // let zDAO decode
    zDAOs[zDAOId].calculateProposal(proposalId, voters, votes);

    emit ProposalCalculated(zDAOId, proposalId, voters, votes);
  }

  function _isZDAODestroyed(uint256 index) internal view returns (bool) {
    return zDAOs[index].destroyed();
  }

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function getZDAOById(uint256 zDAOId)
    external
    view
    override
    returns (IEthereumZDAO)
  {
    return zDAOs[zDAOId];
  }

  function getZDAOInfoById(uint256 zDAOId)
    external
    view
    override
    returns (IEthereumZDAO.ZDAOInfo memory)
  {
    return zDAOs[zDAOId].getZDAOInfo();
  }
}
