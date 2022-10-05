// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {ZeroUpgradeable} from "../../abstracts/ZeroUpgradeable.sol";
import {createProxy} from "../../helpers/Proxy.sol";
import {IPolygonStateSender, IPolygonStateReceiver, ITunnel} from "../interfaces/ITunnel.sol";
import {IChildChainManager} from "./interfaces/IChildChainManager.sol";
import {IPolygonZDAOChef} from "./interfaces/IPolygonZDAOChef.sol";
import {IPolygonZDAO} from "./interfaces/IPolygonZDAO.sol";
import {Staking} from "./Staking.sol";

contract PolygonZDAOChef is
  ZeroUpgradeable,
  IPolygonStateReceiver,
  IPolygonZDAOChef
{
  /**
   * Address to Staking contract, which returns staking power as voting power
   * based on staked amount
   */
  Staking public staking;

  /**
   * Address to ChildChainManagerProxy contract
   * Refer: https://docs.polygon.technology/docs/develop/ethereum-polygon/submit-mapping-request/
   * This contract contains the mapped root and child tokens
   */
  IChildChainManager public childChainManager;

  /**
   * Address to FxStatePolygonTunnel which is responsible for sending message
   * from Ethereum to Polygon
   */
  IPolygonStateSender public polygonStateSender;
  address public zDAOBase;

  mapping(uint256 => IPolygonZDAO) public zDAOs;

  /* -------------------------------------------------------------------------- */
  /*                                  Modifiers                                 */
  /* -------------------------------------------------------------------------- */

  modifier onlyValidZDAO(uint256 zDAOId) {
    require(
      address(zDAOs[zDAOId]) != address(0) && !zDAOs[zDAOId].destroyed(),
      "Invalid zDAO"
    );
    _;
  }

  /* -------------------------------------------------------------------------- */
  /*                                 Initializer                                */
  /* -------------------------------------------------------------------------- */

  function __ZDAOChef_init(
    Staking stakingBase_,
    IPolygonStateSender polygonStateSender_,
    address zDAOBase_,
    IChildChainManager childChainManager_
  ) public initializer {
    ZeroUpgradeable.__ZeroUpgradeable_init();

    staking = stakingBase_;
    polygonStateSender = polygonStateSender_;
    zDAOBase = zDAOBase_;
    childChainManager = childChainManager_;
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function setStaking(Staking staking_) external onlyOwner {
    staking = staking_;

    emit StakingUpdated(address(staking_));
  }

  function setZDAOStaking(uint256 zDAOId, Staking staking_)
    external
    onlyOwner
  {
    require(staking == staking_, "Invalid staking address");
    zDAOs[zDAOId].setStaking(address(staking_));

    emit DAOStakingUpdated(zDAOId, address(staking_));
  }

  function setZDAOBase(address zDAOBase_) external onlyOwner {
    zDAOBase = zDAOBase_;
  }

  function setChildChainManager(IChildChainManager childChainManager_)
    external
    onlyOwner
  {
    childChainManager = childChainManager_;
  }

  /**
   * @notice Cast a vote with user's choice
   * @dev Only for valid zDAO
   * @param zDAOId zDAO unique id
   * @param proposalId Proposal unique id
   * @param choice User's choice, starting from 1
   */
  function vote(
    uint256 zDAOId,
    uint256 proposalId,
    uint256 choice
  ) external override onlyValidZDAO(zDAOId) {
    uint256 vp = zDAOs[zDAOId].vote(proposalId, msg.sender, choice);

    emit CastVote(zDAOId, proposalId, msg.sender, choice, vp);
  }

  /**
   * @notice Calculate proposal, check the comment of calculateProposal function
   *     in the PolygonZDAO contract.
   *     Once calculate proposal, it should be sent to Ethereum.
   * @dev Only for valid zDAO
   * @param zDAOId zDAO unique id
   * @param proposalId Proposal unique id
   */
  function calculateProposal(uint256 zDAOId, uint256 proposalId)
    external
    override
    onlyValidZDAO(zDAOId)
  {
    (uint256 voters, uint256[] memory votes) = zDAOs[zDAOId].calculateProposal(
      proposalId
    );

    emit ProposalCalculated(zDAOId, proposalId, voters, votes);

    // send calculated result to L1
    polygonStateSender.sendMessageToRoot(
      abi.encode(
        uint256(ITunnel.MessageType.CalculateProposal),
        zDAOId,
        proposalId,
        voters,
        votes
      )
    );
  }

  /**
   * @notice Process message from the Ethereum network
   *     The message is encoded by certain format according to protocol type
   * @dev Callable by root state sender
   */
  function processMessageFromRoot(bytes calldata message) external {
    require(msg.sender == address(polygonStateSender), "Not a state sender");
    _processMessageFromRoot(message);
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal Functions                             */
  /* -------------------------------------------------------------------------- */

  function _processMessageFromRoot(bytes memory message) internal {
    uint256 messageType = abi.decode(message, (uint256));
    if (messageType == uint256(MessageType.CreateZDAO)) {
      _createZDAO(message);
    } else if (messageType == uint256(MessageType.DeleteZDAO)) {
      _deleteZDAO(message);
    } else if (messageType == uint256(MessageType.CreateProposal)) {
      _createProposal(message);
    } else if (messageType == uint256(MessageType.CancelProposal)) {
      _cancelProposal(message);
    } else if (messageType == uint256(MessageType.UpdateToken)) {
      _updateToken(message);
    }
  }

  function _createZDAO(bytes memory message)
    internal
    virtual
    returns (IPolygonZDAO)
  {
    (
      uint256 messageType,
      uint256 zDAOId,
      uint256 duration,
      uint256 votingDelay,
      address rootToken
    ) = abi.decode(message, (uint256, uint256, uint256, uint256, address));

    require(address(zDAOs[zDAOId]) == address(0), "zDAO was already created");

    address childToken = childChainManager.rootToChildToken(rootToken);

    IPolygonZDAO zDAO = IPolygonZDAO(
      createProxy(
        zDAOBase,
        abi.encodeWithSelector(
          IPolygonZDAO.__ZDAO_init.selector,
          address(this),
          staking,
          zDAOId,
          duration,
          votingDelay,
          childToken
        )
      )
    );

    zDAOs[zDAOId] = zDAO;

    emit DAOCreated(address(zDAO), zDAOId, childToken, duration, votingDelay);

    return zDAO;
  }

  function _deleteZDAO(bytes memory message) internal virtual {
    (uint256 messageType, uint256 zDAOId) = abi.decode(
      message,
      (uint256, uint256)
    );

    require(zDAOs[zDAOId].getZDAOId() == zDAOId, "Invalid zDAO");

    zDAOs[zDAOId].setDestroyed(true);

    emit DAODestroyed(zDAOId);
  }

  function _createProposal(bytes memory message) internal virtual {
    (
      uint256 messageType,
      uint256 zDAOId,
      uint256 proposalId,
      uint256 numberOfChoices,
      uint256 proposalCreated
    ) = abi.decode(message, (uint256, uint256, uint256, uint256, uint256));

    require(address(zDAOs[zDAOId]) != address(0), "Not created zDAO yet");
    require(zDAOs[zDAOId].getZDAOId() == zDAOId, "Sync zDAO info error");

    zDAOs[zDAOId].createProposal(proposalId, numberOfChoices, proposalCreated);

    emit ProposalCreated(
      zDAOId,
      proposalId,
      numberOfChoices,
      proposalCreated,
      block.timestamp
    );
  }

  function _cancelProposal(bytes memory message) internal virtual {
    (uint256 messageType, uint256 zDAOId, uint256 proposalId) = abi.decode(
      message,
      (uint256, uint256, uint256)
    );

    require(address(zDAOs[zDAOId]) != address(0), "Not created zDAO yet");
    require(zDAOs[zDAOId].getZDAOId() == zDAOId, "Sync zDAO info error");

    zDAOs[zDAOId].cancelProposal(proposalId);

    emit ProposalCanceled(zDAOId, proposalId);
  }

  function _updateToken(bytes memory message) internal virtual {
    (uint256 messageType, uint256 zDAOId, address token) = abi.decode(
      message,
      (uint256, uint256, address)
    );

    require(address(zDAOs[zDAOId]) != address(0), "Not created zDAO yet");
    require(zDAOs[zDAOId].getZDAOId() == zDAOId, "Sync zDAO info error");

    zDAOs[zDAOId].updateToken(token);

    emit DAOTokenUpdated(zDAOId, token);
  }

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function getZDAOById(uint256 zDAOId)
    external
    view
    override
    returns (IPolygonZDAO)
  {
    return zDAOs[zDAOId];
  }

  function getZDAOInfoById(uint256 zDAOId)
    external
    view
    override
    returns (IPolygonZDAO.ZDAOInfo memory)
  {
    return zDAOs[zDAOId].getZDAOInfo();
  }
}
