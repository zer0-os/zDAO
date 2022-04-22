// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {ZeroUpgradeable} from "../abstracts/ZeroUpgradeable.sol";
import {createProxy} from "../helpers/Proxy.sol";
import {IChildStateSender, IChildStateReceiver, ITunnel} from "../interfaces/ITunnel.sol";
import {IPolyZDAOChef} from "./interfaces/IPolyZDAOChef.sol";
import {IPolyZDAO} from "./interfaces/IPolyZDAO.sol";
import {Registry} from "./Registry.sol";
import {Staking} from "./Staking.sol";

contract PolyZDAOChef is ZeroUpgradeable, IChildStateReceiver, IPolyZDAOChef {
  Staking public staking;
  Registry public registry;
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
    Registry _registry,
    IChildStateSender _childStateSender,
    address _zDAOBase
  ) public initializer {
    ZeroUpgradeable.__ZeroUpgradeable_init();

    staking = _stakingBase;
    registry = _registry;
    childStateSender = _childStateSender;
    zDAOBase = _zDAOBase;
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function setStaking(Staking _staking) external onlyOwner {
    staking = _staking;
  }

  function setRegistry(Registry _registry) external onlyOwner {
    registry = _registry;
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

  function collectResult(uint256 _daoId, uint256 _proposalId)
    external
    override
    onlyValidZDAO(_daoId)
  {
    (bool isRelativeMajority, uint256 yes, uint256 no) = zDAOs[_daoId]
      .collectResult(_proposalId);

    emit CollectResult(_daoId, _proposalId, isRelativeMajority, yes, no);

    // send collected result to L1
    childStateSender.sendMessageToRoot(
      abi.encode(
        uint256(ITunnel.MessageType.VoteResult),
        _daoId,
        _proposalId,
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
    }
  }

  function _createZDAO(bytes memory _message)
    internal
    virtual
    returns (IPolyZDAO)
  {
    (
      uint256 messageType,
      uint256 zDAOId,
      address token,
      bool isRelativeMajority,
      uint256 threshold
    ) = abi.decode(_message, (uint256, uint256, address, bool, uint256));

    require(address(zDAOs[zDAOId]) == address(0), "zDAO was already created");

    address mappedToken = registry.rootToChildToken(token); // mapped token from Ethereum
    IPolyZDAO zDAO = IPolyZDAO(
      createProxy(
        zDAOBase,
        abi.encodeWithSelector(
          IPolyZDAO.__ZDAO_init.selector,
          address(this),
          staking,
          zDAOId,
          mappedToken,
          isRelativeMajority,
          threshold
        )
      )
    );

    zDAOs[zDAOId] = zDAO;
    zDAOIds.push(zDAOId);

    // grant locker role to new zDAO
    staking.grantRole(staking.LOCKER_ROLE(), address(zDAO));

    emit DAOCreated(
      address(zDAO),
      zDAOId,
      mappedToken,
      isRelativeMajority,
      threshold
    );

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
      uint256 startTimestamp,
      uint256 endTimestamp
    ) = abi.decode(_message, (uint256, uint256, uint256, uint256, uint256));

    require(address(zDAOs[zDAOId]) != address(0), "Not created zDAO yet");
    require(zDAOs[zDAOId].zDAOId() == zDAOId, "Sync zDAO info error");

    zDAOs[zDAOId].createProposal(proposalId, startTimestamp, endTimestamp);

    emit ProposalCreated(zDAOId, proposalId, startTimestamp, endTimestamp);
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

  function listzDAOs(uint256 _startIndex, uint256 _endIndex)
    external
    view
    returns (IPolyZDAO[] memory)
  {
    require(_startIndex > 0, "should start index > 0");
    require(_startIndex <= _endIndex, "should start index <= end");
    require(_startIndex <= zDAOIds.length, "should start index <= length");
    require(_endIndex <= zDAOIds.length, "should end index <= length");

    uint256 numRecords = _endIndex - _startIndex + 1;
    IPolyZDAO[] memory records = new IPolyZDAO[](numRecords);

    for (uint256 i = 0; i < numRecords; ++i) {
      records[i] = zDAOs[zDAOIds[_startIndex + i - 1]];
    }

    return records;
  }
}
