// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {ZeroUpgradeable} from "../abstracts/ZeroUpgradeable.sol";
import {createProxy} from "../helpers/Proxy.sol";
import {IChildStateSender, IChildStateReceiver, ITunnel} from "../interfaces/ITunnel.sol";
import {IPolyZDAOChef} from "./interfaces/IPolyZDAOChef.sol";
import {IPolyZDAO} from "./interfaces/IPolyZDAO.sol";
import {Staking} from "./Staking.sol";

contract PolyZDAOChef is ZeroUpgradeable, IChildStateReceiver, IPolyZDAOChef {
  Staking public staking;
  IChildStateSender public childStateSender;
  address public zDAOBase;

  mapping(uint256 => IPolyZDAO) public zDAOs;
  uint256[] public zDAOIds;

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
    IChildStateSender _childStateSender,
    address _zDAOBase
  ) public initializer {
    ZeroUpgradeable.__ZeroUpgradeable_init();

    staking = _stakingBase;
    childStateSender = _childStateSender;
    zDAOBase = _zDAOBase;
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function setStaking(Staking _staking) external onlyOwner {
    staking = _staking;
  }

  function setZDAOBase(address _zDAOBase) external onlyOwner {
    zDAOBase = _zDAOBase;
  }

  function vote(
    uint256 _daoId,
    uint256 _proposalId,
    uint256 _choice
  ) external override onlyValidZDAO(_daoId) {
    zDAOs[_daoId].vote(_proposalId, msg.sender, _choice);

    emit CastVote(_daoId, _proposalId, msg.sender, _choice);
  }

  function collectProposal(uint256 _daoId, uint256 _proposalId)
    external
    override
    onlyValidZDAO(_daoId)
  {
    (uint256 voters, uint256 yes, uint256 no) = zDAOs[_daoId].collectProposal(
      _proposalId
    );

    emit ProposalCollected(_daoId, _proposalId, voters, yes, no);

    // send collected result to L1
    childStateSender.sendMessageToRoot(
      abi.encode(
        uint256(ITunnel.MessageType.CollectProposal),
        _daoId,
        _proposalId,
        voters,
        yes,
        no
      )
    );
  }

  function processMessageFromRoot(bytes calldata _message) external {
    require(msg.sender == address(childStateSender), "Not a state sender");
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
    }
  }

  function _createZDAO(bytes memory _message)
    internal
    virtual
    returns (IPolyZDAO)
  {
    (uint256 messageType, uint256 zDAOId) = abi.decode(
      _message,
      (uint256, uint256)
    );

    require(address(zDAOs[zDAOId]) == address(0), "zDAO was already created");

    IPolyZDAO zDAO = IPolyZDAO(
      createProxy(
        zDAOBase,
        abi.encodeWithSelector(
          IPolyZDAO.__ZDAO_init.selector,
          address(this),
          staking,
          zDAOId
        )
      )
    );

    zDAOs[zDAOId] = zDAO;
    zDAOIds.push(zDAOId);

    emit DAOCreated(address(zDAO), zDAOId);

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
    (
      uint256 messageType,
      uint256 zDAOId,
      uint256 proposalId,
      uint256 duration
    ) = abi.decode(_message, (uint256, uint256, uint256, uint256));

    require(address(zDAOs[zDAOId]) != address(0), "Not created zDAO yet");
    require(zDAOs[zDAOId].zDAOId() == zDAOId, "Sync zDAO info error");

    uint256 endTimestamp = block.timestamp + duration;
    zDAOs[zDAOId].createProposal(proposalId, block.timestamp, endTimestamp);

    emit ProposalCreated(zDAOId, proposalId, block.timestamp, endTimestamp);
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

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function numberOfzDAOs() external view override returns (uint256) {
    return zDAOIds.length;
  }

  function getzDAOById(uint256 _daoId) external view returns (IPolyZDAO) {
    return zDAOs[_daoId];
  }

  function listzDAOs(uint256 _startIndex, uint256 _count)
    external
    view
    returns (IPolyZDAO[] memory records)
  {
    uint256 numRecords = _count;
    if (numRecords > (zDAOIds.length - _startIndex)) {
      numRecords = zDAOIds.length - _startIndex;
    }

    records = new IPolyZDAO[](numRecords);

    for (uint256 i = 0; i < numRecords; ++i) {
      records[i] = zDAOs[zDAOIds[_startIndex + i]];
    }

    return records;
  }
}
