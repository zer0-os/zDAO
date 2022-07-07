// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {ZeroUpgradeable} from "../../abstracts/ZeroUpgradeable.sol";
import {createProxy} from "../../helpers/Proxy.sol";
import {IPolygonStateSender, IPolygonStateReceiver, ITunnel} from "../../interfaces/ITunnel.sol";
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
   * Address to FxStatePolygonTunnel which is responsible for sending message
   * from Ethereum to Polygon
   */
  IPolygonStateSender public polygonStateSender;
  address public zDAOBase;

  mapping(uint256 => IPolygonZDAO) public zDAOs;
  uint256[] public zDAOIds;

  /**
   * Address to ChildChainManagerProxy contract
   * Refer: https://docs.polygon.technology/docs/develop/ethereum-polygon/submit-mapping-request/
   * This contract contains the mapped root and child tokens
   */
  IChildChainManager public childChainManager;

  /* -------------------------------------------------------------------------- */
  /*                                  Modifiers                                 */
  /* -------------------------------------------------------------------------- */

  modifier onlyValidZDAO(uint256 _daoId) {
    require(
      address(zDAOs[_daoId]) != address(0) && !zDAOs[_daoId].destroyed(),
      "Invalid zDAO"
    );
    _;
  }

  /* -------------------------------------------------------------------------- */
  /*                                 Initializer                                */
  /* -------------------------------------------------------------------------- */

  function __ZDAOChef_init(
    Staking _stakingBase,
    IPolygonStateSender _polygonStateSender,
    address _zDAOBase,
    IChildChainManager _childChainManager
  ) public initializer {
    ZeroUpgradeable.__ZeroUpgradeable_init();

    staking = _stakingBase;
    polygonStateSender = _polygonStateSender;
    zDAOBase = _zDAOBase;
    childChainManager = _childChainManager;
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function setStaking(Staking _staking) external onlyOwner {
    staking = _staking;

    emit StakingUpdated(address(_staking));
  }

  function setZDAOStaking(uint256 _daoId, Staking _staking) external onlyOwner {
    zDAOs[_daoId].setStaking(address(_staking));

    emit DAOStakingUpdated(_daoId, address(_staking));
  }

  function setZDAOBase(address _zDAOBase) external onlyOwner {
    zDAOBase = _zDAOBase;
  }

  function setChildChainManager(IChildChainManager _childChainManager)
    external
    onlyOwner
  {
    childChainManager = _childChainManager;
  }

  /**
   * @notice Cast a vote with user's choice
   * @dev Only for valid zDAO
   * @param _daoId zDAO unique id
   * @param _proposalId Proposal unique id
   * @param _choice User's choice; yes(1) or no(2)
   */
  function vote(
    uint256 _daoId,
    uint256 _proposalId,
    uint256 _choice
  ) external override onlyValidZDAO(_daoId) {
    zDAOs[_daoId].vote(_proposalId, msg.sender, _choice);

    emit CastVote(_daoId, _proposalId, msg.sender, _choice);
  }

  /**
   * @notice Calculate proposal, check the comment of calculateProposal function
   *     in the PolygonZDAO contract.
   *     Once calculate proposal, it should be sent to Ethereum.
   * @dev Only for valid zDAO
   * @param _daoId zDAO unique id
   * @param _proposalId Proposal unique id
   */
  function calculateProposal(uint256 _daoId, uint256 _proposalId)
    external
    override
    onlyValidZDAO(_daoId)
  {
    (uint256 voters, uint256 yes, uint256 no) = zDAOs[_daoId].calculateProposal(
      _proposalId
    );

    emit ProposalCalculated(_daoId, _proposalId, voters, yes, no);

    // send calculated result to L1
    polygonStateSender.sendMessageToRoot(
      abi.encode(
        uint256(ITunnel.MessageType.CalculateProposal),
        _daoId,
        _proposalId,
        voters,
        yes,
        no
      )
    );
  }

  /**
   * @notice Process message from the Ethereum network
   *     The message is encoded by certain format according to protocol type
   * @dev Callable by root state sender
   */
  function processMessageFromRoot(bytes calldata _message) external {
    require(msg.sender == address(polygonStateSender), "Not a state sender");
    _processMessageFromRoot(_message);
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal Functions                             */
  /* -------------------------------------------------------------------------- */

  function _processMessageFromRoot(bytes memory _message) internal {
    uint256 messageType = abi.decode(_message, (uint256));
    if (messageType == uint256(MessageType.CreateZDAO)) {
      _createZDAO(_message);
    } else if (messageType == uint256(MessageType.DeleteZDAO)) {
      _deleteZDAO(_message);
    } else if (messageType == uint256(MessageType.CreateProposal)) {
      _createProposal(_message);
    } else if (messageType == uint256(MessageType.CancelProposal)) {
      _cancelProposal(_message);
    } else if (messageType == uint256(MessageType.ExecuteProposal)) {
      _executeProposal(_message);
    } else if (messageType == uint256(MessageType.UpdateToken)) {
      _updateToken(_message);
    }
  }

  function _createZDAO(bytes memory _message)
    internal
    virtual
    returns (IPolygonZDAO)
  {
    (
      uint256 messageType,
      uint256 zDAOId,
      uint256 duration,
      address rootToken
    ) = abi.decode(_message, (uint256, uint256, uint256, address));

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
          childToken
        )
      )
    );

    zDAOs[zDAOId] = zDAO;
    zDAOIds.push(zDAOId);

    emit DAOCreated(address(zDAO), zDAOId, duration);

    return zDAO;
  }

  function _deleteZDAO(bytes memory _message) internal virtual {
    (uint256 messageType, uint256 zDAOId) = abi.decode(
      _message,
      (uint256, uint256)
    );

    require(zDAOs[zDAOId].zDAOId() == zDAOId, "Invalid zDAO");

    zDAOs[zDAOId].setDestroyed(true);

    emit DAODestroyed(zDAOId);
  }

  function _createProposal(bytes memory _message) internal virtual {
    (uint256 messageType, uint256 zDAOId, uint256 proposalId) = abi.decode(
      _message,
      (uint256, uint256, uint256)
    );

    require(address(zDAOs[zDAOId]) != address(0), "Not created zDAO yet");
    require(zDAOs[zDAOId].zDAOId() == zDAOId, "Sync zDAO info error");

    zDAOs[zDAOId].createProposal(proposalId, block.timestamp);

    emit ProposalCreated(zDAOId, proposalId, block.timestamp);
  }

  function _cancelProposal(bytes memory _message) internal virtual {
    (uint256 messageType, uint256 zDAOId, uint256 proposalId) = abi.decode(
      _message,
      (uint256, uint256, uint256)
    );

    require(address(zDAOs[zDAOId]) != address(0), "Not created zDAO yet");
    require(zDAOs[zDAOId].zDAOId() == zDAOId, "Sync zDAO info error");

    zDAOs[zDAOId].cancelProposal(proposalId);

    emit ProposalCanceled(zDAOId, proposalId);
  }

  function _executeProposal(bytes memory _message) internal virtual {
    (uint256 messageType, uint256 zDAOId, uint256 proposalId) = abi.decode(
      _message,
      (uint256, uint256, uint256)
    );

    require(address(zDAOs[zDAOId]) != address(0), "Not created zDAO yet");
    require(zDAOs[zDAOId].zDAOId() == zDAOId, "Sync zDAO info error");

    zDAOs[zDAOId].executeProposal(proposalId);

    emit ProposalExecuted(zDAOId, proposalId);
  }

  function _updateToken(bytes memory _message) internal virtual {
    (uint256 messageType, uint256 zDAOId, address token) = abi.decode(
      _message,
      (uint256, uint256, address)
    );

    require(address(zDAOs[zDAOId]) != address(0), "Not created zDAO yet");
    require(zDAOs[zDAOId].zDAOId() == zDAOId, "Sync zDAO info error");

    zDAOs[zDAOId].updateToken(token);

    emit DAOTokenUpdated(zDAOId, token);
  }

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function numberOfzDAOs() external view override returns (uint256) {
    return zDAOIds.length;
  }

  function getzDAOById(uint256 _daoId) external view returns (IPolygonZDAO) {
    return zDAOs[_daoId];
  }

  function listzDAOs(uint256 _startIndex, uint256 _count)
    external
    view
    returns (IPolygonZDAO[] memory records)
  {
    uint256 numRecords = _count;
    if (numRecords > (zDAOIds.length - _startIndex)) {
      numRecords = zDAOIds.length - _startIndex;
    }

    records = new IPolygonZDAO[](numRecords);

    for (uint256 i = 0; i < numRecords; ++i) {
      records[i] = zDAOs[zDAOIds[_startIndex + i]];
    }

    return records;
  }
}
