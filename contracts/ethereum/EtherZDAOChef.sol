// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {ZeroUpgradeable, IERC20Upgradeable} from "../abstracts/ZeroUpgradeable.sol";
import {createProxy} from "../helpers/Proxy.sol";
import {IZNSHub} from "../interfaces/IZNSHub.sol";
import {IRootStateSender, IRootStateReceiver, ITunnel} from "../interfaces/ITunnel.sol";
import {IEtherZDAOChef} from "./interfaces/IEtherZDAOChef.sol";
import {IEtherZDAO} from "./interfaces/IEtherZDAO.sol";
import {console} from "hardhat/console.sol";

contract EtherZDAOChef is ZeroUpgradeable, IRootStateReceiver, IEtherZDAOChef {
  IZNSHub public znsHub;
  IRootStateSender public rootStateSender;
  address public zDAOBase;

  mapping(uint256 => ZDAORecord) public zDAORecords;
  mapping(uint256 => uint256) private zNATozDAOId;

  uint256 public lastZDAOId;

  /* -------------------------------------------------------------------------- */
  /*                                  Modifiers                                 */
  /* -------------------------------------------------------------------------- */

  modifier onlyZNAOwner(uint256 _zNA) {
    require(znsHub.ownerOf(_zNA) == msg.sender, "Not a zNA owner");
    _;
  }

  modifier onlyValidZDAO(uint256 _daoId) {
    require(
      _daoId > 0 && _daoId <= lastZDAOId && !_isZDAODestroyed(_daoId),
      "Invalid zDAO"
    );
    _;
  }

  modifier onlyDAOOwner(uint256 _daoId) {
    require(
      msg.sender == zDAORecords[_daoId].zDAO.zDAOOwner(),
      "Invalid zDAO Owner"
    );
    _;
  }

  /* -------------------------------------------------------------------------- */
  /*                                 Initializer                                */
  /* -------------------------------------------------------------------------- */

  function __ZDAOChef_init(
    IZNSHub _znsHub,
    IRootStateSender _rootStateSender,
    address _zDAOBase
  ) public initializer {
    ZeroUpgradeable.__ZeroUpgradeable_init();

    znsHub = _znsHub;
    rootStateSender = _rootStateSender;
    zDAOBase = _zDAOBase;
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function setZNSHub(address _znsHub) external onlyOwner {
    znsHub = IZNSHub(_znsHub);
  }

  function setZDAOBase(address _zDAOBase) external onlyOwner {
    zDAOBase = _zDAOBase;
  }

  function addNewDAO(uint256 _zNA, ZDAOConfig calldata _zDAOConfig)
    external
    override
    onlyZNAOwner(_zNA)
  {
    uint256 daoId = zNATozDAOId[_zNA];
    require(daoId == 0, "Do not allow to add new DAO with same zNA");

    // Create zDAO contract
    IEtherZDAO zDAO = _createZDAO(_zDAOConfig);

    zDAORecords[lastZDAOId] = ZDAORecord({
      id: lastZDAOId,
      zDAO: zDAO,
      associatedzNAs: new uint256[](0)
    });

    emit DAOCreated(lastZDAOId, msg.sender, address(zDAO));

    // Associate zDAO with zNA
    _associatezNA(lastZDAOId, _zNA);

    // send zDAO info to L2
    rootStateSender.sendMessageToChild(
      abi.encode(
        uint256(MessageType.CreateZDAO),
        lastZDAOId,
        address(_zDAOConfig.token),
        _zDAOConfig.isRelativeMajority,
        _zDAOConfig.quorumVotes
      )
    );
  }

  function removeDAO(uint256 _daoId)
    external
    override
    onlyDAOOwner(_daoId)
    onlyValidZDAO(_daoId)
  {
    zDAORecords[_daoId].zDAO.setDestroyed(true);

    emit DAODestroyed(_daoId);

    // send zDAO info to L2
    rootStateSender.sendMessageToChild(
      abi.encode(uint256(MessageType.DeleteZDAO), _daoId)
    );
  }

  function setDAOGnosisSafe(uint256 _daoId, address _gnosisSafe)
    external
    override
    onlyDAOOwner(_daoId)
    onlyValidZDAO(_daoId)
  {
    zDAORecords[_daoId].zDAO.setGnosisSafe(_gnosisSafe);

    emit DAOUpdateGnosisSafe(_daoId, _gnosisSafe);
  }

  function setDAOVotingToken(
    uint256 _daoId,
    address _token,
    uint256 _amount
  ) external override onlyDAOOwner(_daoId) onlyValidZDAO(_daoId) {
    zDAORecords[_daoId].zDAO.setVotingToken(_token, _amount);

    emit DAOUpdateVotingtoken(_daoId, _token, _amount);

    // todo, send message to L2
  }

  function addZNAAssociation(uint256 _daoId, uint256 _zNA)
    external
    override
    onlyValidZDAO(_daoId)
    onlyZNAOwner(_zNA)
  {
    _associatezNA(_daoId, _zNA);
  }

  function removeZNAAssociation(uint256 _daoId, uint256 _zNA)
    external
    override
    onlyValidZDAO(_daoId)
    onlyZNAOwner(_zNA)
  {
    uint256 currentDAOAssociation = zNATozDAOId[_zNA];
    require(currentDAOAssociation == _daoId, "zNA not associated");

    _disassociatezNA(_daoId, _zNA);
  }

  function createProposal(
    uint256 _daoId,
    uint256 _duration,
    address _target,
    uint256 _value,
    bytes calldata _data,
    string calldata _ipfs
  ) external override onlyValidZDAO(_daoId) {
    uint256 proposalId = zDAORecords[_daoId].zDAO.createProposal(
      msg.sender, // created by
      _duration,
      _target,
      _value,
      _data,
      _ipfs
    );

    emit ProposalCreated(
      _daoId,
      proposalId,
      msg.sender,
      _duration,
      uint256(block.number)
    );

    // send proposal info to L2
    rootStateSender.sendMessageToChild(
      abi.encode(
        uint256(ITunnel.MessageType.CreateProposal),
        _daoId,
        proposalId,
        _duration
      )
    );
  }

  function cancelProposal(uint256 _daoId, uint256 _proposalId)
    external
    override
  {
    zDAORecords[_daoId].zDAO.cancelProposal(msg.sender, _proposalId);

    emit ProposalCanceled(_daoId, _proposalId, msg.sender);

    rootStateSender.sendMessageToChild(
      abi.encode(
        uint256(ITunnel.MessageType.CancelProposal),
        _daoId,
        _proposalId
      )
    );
  }

  function executeProposal(uint256 _daoId, uint256 _proposalId)
    external
    override
  {
    zDAORecords[_daoId].zDAO.executeProposal(msg.sender, _proposalId);

    emit ProposalExecuted(_daoId, _proposalId, msg.sender);

    rootStateSender.sendMessageToChild(
      abi.encode(
        uint256(ITunnel.MessageType.ExecuteProposal),
        _daoId,
        _proposalId
      )
    );
  }

  function processMessageFromChild(bytes calldata _message) external override {
    require(msg.sender == address(rootStateSender), "Not a state sender");
    _processMessageFromChild(_message);
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal Functions                             */
  /* -------------------------------------------------------------------------- */

  function _processMessageFromChild(bytes memory _message) internal {
    uint256 messageType = abi.decode(_message, (uint256));
    if (messageType == uint256(ITunnel.MessageType.VoteResult)) {
      _collectProposal(_message);
    }
  }

  function _collectProposal(bytes memory _message) internal virtual {
    (
      uint256 messageType2,
      uint256 zDAOId,
      uint256 proposalId,
      uint256 yes,
      uint256 no
    ) = abi.decode(_message, (uint256, uint256, uint256, uint256, uint256));
    require(zDAOId > 0 && zDAOId <= lastZDAOId, "Invalid zDAO");

    // let zDAO decode
    zDAORecords[zDAOId].zDAO.setVoteResult(proposalId, yes, no);

    emit ProposalCollected(zDAOId, proposalId, yes, no);
  }

  function _isZDAODestroyed(uint256 _index) internal view returns (bool) {
    return zDAORecords[_index].zDAO.destroyed();
  }

  function _createZDAO(ZDAOConfig calldata _zDAOConfig)
    internal
    virtual
    returns (IEtherZDAO zDAO)
  {
    lastZDAOId++;

    zDAO = IEtherZDAO(
      createProxy(
        zDAOBase,
        abi.encodeWithSelector(
          IEtherZDAO.__ZDAO_init.selector,
          address(this),
          lastZDAOId,
          msg.sender, // zDAO createdBy
          _zDAOConfig
        )
      )
    );
  }

  function _associatezNA(uint256 _daoId, uint256 _zNA) internal {
    uint256 currentDAOAssociation = zNATozDAOId[_zNA];
    require(currentDAOAssociation != _daoId, "zNA already linked to DAO");

    // If an association already exists, remove it
    if (currentDAOAssociation != 0) {
      _disassociatezNA(currentDAOAssociation, _zNA);
    }

    zNATozDAOId[_zNA] = _daoId;
    zDAORecords[_daoId].associatedzNAs.push(_zNA);

    emit LinkAdded(_daoId, _zNA);
  }

  function _disassociatezNA(uint256 daoId, uint256 zNA) internal {
    ZDAORecord storage dao = zDAORecords[daoId];
    uint256 length = zDAORecords[daoId].associatedzNAs.length;

    for (uint256 i = 0; i < length; i++) {
      if (dao.associatedzNAs[i] == zNA) {
        dao.associatedzNAs[i] = dao.associatedzNAs[length - 1];
        dao.associatedzNAs.pop();
        zNATozDAOId[zNA] = 0;

        emit LinkRemoved(daoId, zNA);
        break;
      }
    }
  }

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function numberOfzDAOs() external view override returns (uint256) {
    uint256 count = 0;
    for (uint256 i = 1; i <= lastZDAOId; i++) {
      count += !_isZDAODestroyed(i) ? 1 : 0;
    }
    return count;
  }

  function getzDAOById(uint256 _daoId)
    external
    view
    override
    returns (ZDAORecord memory)
  {
    return zDAORecords[_daoId];
  }

  function listzDAOs(uint256 _startIndex, uint256 _endIndex)
    external
    view
    override
    returns (ZDAORecord[] memory)
  {
    require(_startIndex > 0, "should start index > 0");
    require(_startIndex <= _endIndex, "should start index <= end");
    require(_startIndex <= lastZDAOId, "should start index <= length");
    require(_endIndex <= lastZDAOId, "should end index <= length");

    uint256 numRecords = _endIndex - _startIndex + 1;
    ZDAORecord[] memory records = new ZDAORecord[](numRecords);

    for (uint256 i = 0; i < numRecords; ++i) {
      records[i] = zDAORecords[_startIndex + i];
    }

    return records;
  }

  function getzDaoByZNA(uint256 _zNA)
    external
    view
    override
    returns (ZDAORecord memory)
  {
    uint256 daoId = zNATozDAOId[_zNA];
    require(
      daoId > 0 && daoId <= lastZDAOId && !_isZDAODestroyed(daoId),
      "No zDAO associated with zNA"
    );
    return zDAORecords[daoId];
  }

  function doeszDAOExistForzNA(uint256 _zNA)
    external
    view
    override
    returns (bool)
  {
    return zNATozDAOId[_zNA] != 0;
  }
}
