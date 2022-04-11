// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "../abstracts/ZDAOUpgradeable.sol";
import "../interfaces/IZNSHub.sol";
import "../libraries/ZDAOLib.sol";
import "./ZDAO.sol";

contract ZDAOChef is ZDAOUpgradeable, IRootTunnel {
  using SafeMathUpgradeable for uint256;
  using ZDAOLib for ZDAOLib.ZDAOInfo;

  struct ZDAORecord {
    uint256 id;
    ZDAO zDAO; // address to newly created ZDAO contract
    uint256[] associatedzNAs;
  }

  mapping(uint256 => ZDAORecord) public zDAORecords;
  mapping(uint256 => uint256) private zNATozDAOId;

  uint256 private lastZDAOId;

  IZNSHub public znsHub;

  /* -------------------------------------------------------------------------- */
  /*                                   Events                                   */
  /* -------------------------------------------------------------------------- */

  event DAOCreated(
    uint256 indexed _daoId,
    address indexed _creator,
    address indexed _zDAO
  );

  event DAODestroyed(uint256 indexed _daoId);

  event LinkAdded(uint256 indexed _daoId, uint256 indexed _zNA);

  event LinkRemoved(uint256 indexed _daoId, uint256 indexed _zNA);

  /* -------------------------------------------------------------------------- */
  /*                                  Modifiers                                 */
  /* -------------------------------------------------------------------------- */

  modifier onlyZNAOwner(uint256 _zNA) {
    require(znsHub.ownerOf(_zNA) == msg.sender, "Not a zNA owner");
    _;
  }

  modifier onlyValidZDAO(uint256 _daoId) {
    require(
      _daoId > 0 &&
        _daoId <= lastZDAOId &&
        !zDAORecords[_daoId].zDAO.destroyed(),
      "Invalid zDAO"
    );
    _;
  }

  /* -------------------------------------------------------------------------- */
  /*                                 Initializer                                */
  /* -------------------------------------------------------------------------- */

  function zDAOChefInitializer(IZNSHub _znsHub) public initializer {
    ZDAOUpgradeable.initialize();

    znsHub = _znsHub;
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function setZNSHub(address _znsHub) external onlyOwner {
    znsHub = IZNSHub(_znsHub);
  }

  function addNewDAO(uint256 _zNA, ZDAOLib.ZDAOInfo calldata _zDAOInfo)
    external
    onlyZNAOwner(_zNA)
  {
    lastZDAOId++;

    // Create zDAO contract
    ZDAO zDAO = new ZDAO(
      IRootTunnel(this),
      ZDAOLib.ZDAOInfo({
        id: lastZDAOId,
        owner: msg.sender,
        name: _zDAOInfo.name,
        gnosisSafe: _zDAOInfo.gnosisSafe,
        token: _zDAOInfo.token,
        amount: _zDAOInfo.amount,
        destroyed: false
      })
    );

    zDAORecords[lastZDAOId] = ZDAORecord({
      id: lastZDAOId,
      zDAO: zDAO,
      associatedzNAs: new uint256[](0)
    });

    emit DAOCreated(lastZDAOId, msg.sender, address(zDAO));

    // Associate zDAO with zNA
    _associatezNA(lastZDAOId, _zNA);
  }

  function removeDAO(uint256 _daoId) external onlyOwner onlyValidZDAO(_daoId) {
    zDAORecords[_daoId].zDAO.setDestroyed(false);

    emit DAODestroyed(_daoId);
  }

  function addZNAAssociation(uint256 _daoId, uint256 _zNA)
    external
    onlyValidZDAO(_daoId)
    onlyZNAOwner(_zNA)
  {
    _associatezNA(_daoId, _zNA);
  }

  function removeZNAAssociation(uint256 _daoId, uint256 _zNA)
    external
    onlyValidZDAO(_daoId)
    onlyZNAOwner(_zNA)
  {
    uint256 currentDAOAssociation = zNATozDAOId[_zNA];
    require(currentDAOAssociation == _daoId, "zNA not associated");

    _disassociatezNA(_daoId, _zNA);
  }

  function sendMessageToChild(bytes memory message) external {
    // TODO
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal Functions                             */
  /* -------------------------------------------------------------------------- */

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
  function numberOfzDAOs() external view returns (uint256) {
    return lastZDAOId;
  }

  function getzDAOById(uint256 _daoId)
    external
    view
    returns (ZDAORecord memory)
  {
    return zDAORecords[_daoId];
  }

  function listzDAOs(uint256 _startIndex, uint256 _endIndex)
    external
    view
    returns (ZDAORecord[] memory)
  {
    require(_startIndex <= _endIndex, "start index > end");
    require(_startIndex <= lastZDAOId, "start index > length");
    require(_endIndex <= lastZDAOId, "end index > length");

    uint256 numRecords = _endIndex - _startIndex + 1;
    ZDAORecord[] memory records = new ZDAORecord[](numRecords);

    for (uint256 i = 0; i < numRecords; ++i) {
      records[i] = zDAORecords[_startIndex + i + 1];
    }

    return records;
  }

  function getzDaoByZNA(uint256 _zNA)
    external
    view
    returns (ZDAORecord memory)
  {
    uint256 daoId = zNATozDAOId[_zNA];
    require(
      daoId > 0 && daoId <= lastZDAOId && !zDAORecords[daoId].zDAO.destroyed(),
      "No zDAO associated with zNA"
    );
    return zDAORecords[daoId];
  }

  function doeszDAOExistForzNA(uint256 _zNA) external view returns (bool) {
    return zNATozDAOId[_zNA] != 0;
  }
}
