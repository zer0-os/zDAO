// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "../abstracts/ZeroUpgradeable.sol";
import "../interfaces/IZNSHub.sol";
import "../helpers/Proxy.sol";
import "../tunnel/FxBaseRootTunnel.sol";
import "./interfaces/IRootTunnel.sol";
import "./interfaces/IEtherZDAOChef.sol";
import "./EtherZDAO.sol";
import "hardhat/console.sol";

contract EtherZDAOChef is
  ZeroUpgradeable,
  FxBaseRootTunnel,
  IRootTunnel,
  IEtherZDAOChef
{
  address public zDAOBase;

  mapping(uint256 => ZDAORecord) public zDAORecords;
  mapping(uint256 => uint256) private zNATozDAOId;

  uint256 private lastZDAOId;

  IZNSHub public znsHub;

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
    address _zDAOBase,
    address _checkpointManager,
    address _fxRoot
  ) public initializer {
    ZeroUpgradeable.initialize();

    znsHub = _znsHub;
    zDAOBase = _zDAOBase;

    checkpointManager = ICheckpointManager(_checkpointManager);
    fxRoot = IFxStateSender(_fxRoot);
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function setZNSHub(address _znsHub) external onlyOwner {
    znsHub = IZNSHub(_znsHub);
  }

  function addNewDAO(uint256 _zNA, ZDAOConfig calldata _zDAOConfig)
    external
    override
    onlyZNAOwner(_zNA)
  {
    uint256 daoId = zNATozDAOId[_zNA];
    require(daoId == 0, "Do not allow to add new DAO with same zNA");

    // Create zDAO contract
    EtherZDAO zDAO = _createZDAO(_zDAOConfig);

    zDAORecords[lastZDAOId] = ZDAORecord({
      id: lastZDAOId,
      zDAO: zDAO,
      associatedzNAs: new uint256[](0)
    });

    emit DAOCreated(lastZDAOId, msg.sender, address(zDAO));

    // Associate zDAO with zNA
    _associatezNA(lastZDAOId, _zNA);

    // send zDAO info to L2
    _sendMessageToChild(
      abi.encode(
        uint256(MessageType.CreateZDAO),
        lastZDAOId,
        bytes(_zDAOConfig.name),
        zDAO.zDAOOwner(),
        address(_zDAOConfig.token),
        _zDAOConfig.isRelativeMajority,
        _zDAOConfig.threshold
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
    _sendMessageToChild(abi.encode(uint256(MessageType.DeleteZDAO), _daoId));
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

  function sendMessageToChild(bytes memory _message) external override {
    _sendMessageToChild(_message);
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal Functions                             */
  /* -------------------------------------------------------------------------- */

  function _processMessageFromChild(bytes memory _data) internal override {
    uint256 messageType = abi.decode(_data, (uint256));
    if (messageType == uint256(ITunnel.MessageType.VoteResult)) {
      (uint256 messageType2, uint256 zDAOId) = abi.decode(
        _data,
        (uint256, uint256)
      );
      // let zDAO decode
      zDAORecords[zDAOId].zDAO.setVoteResult(_data);
    }
  }

  function _isZDAODestroyed(uint256 _index) internal view returns (bool) {
    return zDAORecords[_index].zDAO.destroyed();
  }

  function _createZDAO(ZDAOConfig calldata _zDAOConfig)
    internal
    virtual
    returns (EtherZDAO zDAO)
  {
    lastZDAOId++;

    zDAO = EtherZDAO(
      createProxy(
        zDAOBase,
        abi.encodeWithSelector(
          EtherZDAO.__ZDAO_init.selector,
          IRootTunnel(this),
          lastZDAOId,
          msg.sender,
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
