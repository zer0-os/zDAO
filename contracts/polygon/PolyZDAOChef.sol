// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "../abstracts/ZeroUpgradeable.sol";
import "../helpers/Proxy.sol";
import "../tunnel/FxBaseChildTunnel.sol";
import "./interfaces/IChildTunnel.sol";
import "./interfaces/IPolyZDAOChef.sol";
import "../helpers/Proxy.sol";
import "./PolyZDAO.sol";
import "./Registry.sol";
import "./Staking.sol";

contract PolyZDAOChef is
  ZeroUpgradeable,
  FxBaseChildTunnel,
  IChildTunnel,
  IPolyZDAOChef
{
  Staking public staking;
  Registry public registry;
  address public zDAOBase;

  mapping(uint256 => PolyZDAO) public zDAOs;
  uint256[] public zDAOIds;

  /* -------------------------------------------------------------------------- */
  /*                                  Modifiers                                 */
  /* -------------------------------------------------------------------------- */

  /* -------------------------------------------------------------------------- */
  /*                                 Initializer                                */
  /* -------------------------------------------------------------------------- */

  function __ZDAOChef_init(
    Staking _stakingBase,
    Registry _registry,
    address _zDAOBase,
    address _fxChild
  ) public initializer {
    ZeroUpgradeable.initialize();

    staking = _stakingBase;
    registry = _registry;
    zDAOBase = _zDAOBase;
    fxChild = _fxChild;
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

  function setFxRootTunnel(address _fxRootTunnel) external onlyOwner {
    fxRootTunnel = _fxRootTunnel;
  }

  function sendMessageToRoot(bytes memory _message) external {
    _sendMessageToRoot(_message);
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal Functions                             */
  /* -------------------------------------------------------------------------- */

  function _processMessageFromRoot(
    uint256,
    address,
    bytes memory data
  ) internal override {
    uint256 messageType = abi.decode(data, (uint256));
    if (messageType == uint256(MessageType.CreateZDAO)) {
      // create zDAO
      _createZDAO(data);
    } else if (messageType == uint256(MessageType.DeleteZDAO)) {
      _deleteZDAO(data);
    } else if (messageType == uint256(MessageType.CreateProposal)) {
      _createProposal(data);
    }
  }

  function _createZDAO(bytes memory data) internal virtual returns (PolyZDAO) {
    (
      uint256 messageType,
      uint256 zDAOId,
      address token,
      bool isRelativeMajority,
      uint256 threshold
    ) = abi.decode(data, (uint256, uint256, address, bool, uint256));

    require(address(zDAOs[zDAOId]) == address(0), "zDAO was already created");

    address mappedToken = registry.rootToChildToken(token); // mapped token from Ethereum
    PolyZDAO zDAO = PolyZDAO(
      createProxy(
        zDAOBase,
        abi.encodeWithSelector(
          PolyZDAO.__ZDAO_init.selector,
          IChildTunnel(this),
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

  function _deleteZDAO(bytes memory data) internal virtual {
    (uint256 messageType, uint256 zDAOId) = abi.decode(
      data,
      (uint256, uint256)
    );

    require(zDAOs[zDAOId].zDAOId() == zDAOId, "Invalid zDAO");

    zDAOs[zDAOId].setDestroyed(true);

    emit DAODestroyed(zDAOId);
  }

  function _createProposal(bytes memory data) internal virtual {
    (
      uint256 messageType,
      uint256 zDAOId,
      uint256 proposalId,
      uint256 startTimestamp,
      uint256 endTimestamp
    ) = abi.decode(data, (uint256, uint256, uint256, uint256, uint256));

    require(address(zDAOs[zDAOId]) != address(0), "Not created zDAO yet");
    require(zDAOs[zDAOId].zDAOId() == zDAOId, "Sync zDAO info error");

    zDAOs[zDAOId].createProposal(proposalId, startTimestamp, endTimestamp);
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
