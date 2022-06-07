// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {ZeroUpgradeable, IERC20Upgradeable} from "../../abstracts/ZeroUpgradeable.sol";
import {createProxy} from "../../helpers/Proxy.sol";
import {IZNSHub} from "../../interfaces/IZNSHub.sol";
import {IRootStateSender, IRootStateReceiver, ITunnel} from "../../interfaces/ITunnel.sol";
import {IRootZDAOChef} from "./interfaces/IRootZDAOChef.sol";
import {IRootZDAO} from "./interfaces/IRootZDAO.sol";
import {console} from "hardhat/console.sol";

contract RootZDAOChef is ZeroUpgradeable, IRootStateReceiver, IRootZDAOChef {
  IZNSHub public znsHub;
  /**
   * Address to FxStateRootTunnel which is responsible for sending message
   * from Ethereum to Polygon
   */
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

  /**
   * @notice Add new zDAO associating with given zNA.
   *     Create new RootZDAO contract and associate new zDAO with given zNA.
   *     Once create new zDAO, it should be synchronized to Polygon.
   *     Users can create proposal and cast a vote after zDAO synchronization.
   * @dev Only zNA owner can create zDAO
   * @param _zNA zNA unique Id
   * @param _zDAOConfig Structure of zDAO information
   */
  function addNewDAO(uint256 _zNA, ZDAOConfig calldata _zDAOConfig)
    external
    override
    onlyZNAOwner(_zNA)
  {
    uint256 daoId = zNATozDAOId[_zNA];
    require(daoId == 0, "Do not allow to add new DAO with same zNA");

    // Create zDAO contract
    IRootZDAO zDAO = _createZDAO(_zDAOConfig);

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
        _zDAOConfig.duration,
        _zDAOConfig.token
      )
    );
  }

  /**
   * @notice Remove zDAO by zDAOId.
   *     Removed state should be synchronized to Polygon, so that stop
   *     user voting
   * @dev Only zDAO owner can remove zDAO, and only for valid zDAO
   * @param _daoId zDAO unique id
   */
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

  /**
   * @notice Set Gnosis Safe address for given zDAO
   * @dev Callable by zDAO owner and for valid zDAO
   * @param _daoId zDAO unique id
   * @param _gnosisSafe Address to Gnosis Safe
   */
  function setDAOGnosisSafe(uint256 _daoId, address _gnosisSafe)
    external
    override
    onlyDAOOwner(_daoId)
    onlyValidZDAO(_daoId)
  {
    zDAORecords[_daoId].zDAO.setGnosisSafe(_gnosisSafe);

    emit DAOUpdateGnosisSafe(_daoId, _gnosisSafe);
  }

  /**
   * @notice Set voting token and minimum holding amount
   * @dev Callable by zDAO owner and for valid zDAO
   * @param _daoId zDAO unique id
   * @param _token Voting token address, ERC20 or ERc721
   * @param _amount Minimum holding amount required to become proposal creator
   */
  function setDAOVotingToken(
    uint256 _daoId,
    address _token,
    uint256 _amount
  ) external override onlyDAOOwner(_daoId) onlyValidZDAO(_daoId) {
    zDAORecords[_daoId].zDAO.setVotingToken(_token, _amount);

    emit DAOUpdateVotingtoken(_daoId, _token, _amount);

    // todo, send message to L2
    // send proposal info to L2
    rootStateSender.sendMessageToChild(
      abi.encode(uint256(ITunnel.MessageType.UpdateToken), _daoId, _token)
    );
  }

  /**
   * @notice Add association with zNA
   * @dev Callable by zDAO owner and for valid zDAO
   * @param _daoId zDAO unique id
   * @param _zNA zNA id required to associate
   */
  function addZNAAssociation(uint256 _daoId, uint256 _zNA)
    external
    override
    onlyValidZDAO(_daoId)
    onlyZNAOwner(_zNA)
  {
    _associatezNA(_daoId, _zNA);
  }

  /**
   * @notice Remove association from given zDAO
   * @dev Callable by zDAO owner and for valid zDAO
   * @param _daoId zDAO unique id
   * @param _zNA zNA id required to remove
   */
  function removeZNAAssociation(uint256 _daoId, uint256 _zNA)
    external
    override
    onlyZNAOwner(_zNA)
  {
    require(_daoId > 0 && _daoId <= lastZDAOId, "Invalid zDAO");
    require(zNATozDAOId[_zNA] == _daoId, "zNA not associated");

    _disassociatezNA(_daoId, _zNA);
  }

  /**
   * @notice Create a proposal, check the comment of createProposal function
   *     in the RootZDAO contract.
   *     Once create a new proposal, it should be synchronized to Polygon.
   * @dev Only for valid zDAO
   * @param _daoId zDAO unique id
   * @param _ipfs IPFS which contains proposal information
   */
  function createProposal(uint256 _daoId, string calldata _ipfs)
    external
    override
    onlyValidZDAO(_daoId)
  {
    uint256 proposalId = zDAORecords[_daoId].zDAO.createProposal(
      msg.sender, // created by
      _ipfs
    );

    emit ProposalCreated(_daoId, proposalId, msg.sender, uint256(block.number));

    // send proposal info to L2
    rootStateSender.sendMessageToChild(
      abi.encode(
        uint256(ITunnel.MessageType.CreateProposal),
        _daoId,
        proposalId
      )
    );
  }

  /**
   * @notice Cancel proposal, check the comment of cancelProposal function
   *     in the RootZDAO contract.
   * @dev Only for valid zDAO
   * @param _daoId zDAO unique id
   * @param _proposalId Proposal unique id
   */
  function cancelProposal(uint256 _daoId, uint256 _proposalId)
    external
    override
    onlyValidZDAO(_daoId)
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

  /**
   * @notice Execute proposal, check the comment of executeProposal function
   *     in the RootZDAO contract.
   * @dev Only for valid zDAO
   * @param _daoId zDAO unique id
   * @param _proposalId Proposal unique id
   */
  function executeProposal(uint256 _daoId, uint256 _proposalId)
    external
    override
    onlyValidZDAO(_daoId)
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

  /**
   * @notice Process message from the Polygon network
   *     The message is encoded by certain format according to protocol type
   * @dev Callable by root state sender
   */
  function processMessageFromChild(bytes calldata _message) external override {
    require(msg.sender == address(rootStateSender), "Not a state sender");
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
    require(
      zDAOId > 0 && zDAOId <= lastZDAOId && !_isZDAODestroyed(lastZDAOId),
      "Invalid zDAO"
    );

    // let zDAO decode
    zDAORecords[zDAOId].zDAO.calculateProposal(proposalId, voters, yes, no);

    emit ProposalCalculated(zDAOId, proposalId, voters, yes, no);
  }

  function _isZDAODestroyed(uint256 _index) internal view returns (bool) {
    return zDAORecords[_index].zDAO.destroyed();
  }

  function _createZDAO(ZDAOConfig calldata _zDAOConfig)
    internal
    virtual
    returns (IRootZDAO zDAO)
  {
    lastZDAOId++;

    zDAO = IRootZDAO(
      createProxy(
        zDAOBase,
        abi.encodeWithSelector(
          IRootZDAO.__ZDAO_init.selector,
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
    return lastZDAOId;
  }

  function getzDAOById(uint256 _daoId)
    external
    view
    override
    returns (ZDAORecord memory)
  {
    return zDAORecords[_daoId];
  }

  function listzDAOs(uint256 _startIndex, uint256 _count)
    external
    view
    override
    returns (ZDAORecord[] memory records)
  {
    uint256 numRecords = _count;
    if (numRecords > (lastZDAOId - _startIndex)) {
      numRecords = lastZDAOId - _startIndex;
    }

    records = new ZDAORecord[](numRecords);

    for (uint256 i = 0; i < numRecords; ++i) {
      records[i] = zDAORecords[_startIndex + i + 1];
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
    require(daoId > 0 && daoId <= lastZDAOId, "No zDAO associated with zNA");
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
