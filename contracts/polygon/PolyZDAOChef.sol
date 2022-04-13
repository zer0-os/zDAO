// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "../abstracts/ZeroUpgradeable.sol";
import "../helpers/Proxy.sol";
import "../tunnel/FxBaseChildTunnel.sol";
import "./interfaces/IChildTunnel.sol";
import "./interfaces/IPolyZDAOChef.sol";
import "../helpers/Proxy.sol";
import "./PolyZDAO.sol";

contract PolyZDAOChef is
  ZeroUpgradeable,
  FxBaseChildTunnel,
  IChildTunnel,
  IPolyZDAOChef
{
  address public zDAOBase;

  mapping(uint256 => PolyZDAO) public zDAOs;
  uint256[] public zDAOIds;

  /* -------------------------------------------------------------------------- */
  /*                                  Modifiers                                 */
  /* -------------------------------------------------------------------------- */

  /* -------------------------------------------------------------------------- */
  /*                                 Initializer                                */
  /* -------------------------------------------------------------------------- */

  function __ZDAOChef_init(address _zDAOBase, address _fxChild)
    public
    initializer
  {
    ZeroUpgradeable.initialize();

    zDAOBase = _zDAOBase;
    fxChild = _fxChild;
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

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
    } else if (messageType == uint256(MessageType.CreateProposal)) {
      _createProposal(data);
    }
  }

  function _createZDAO(bytes memory data) internal virtual returns (PolyZDAO) {
    (
      uint256 messageType,
      uint256 zDAOId,
      bytes memory name,
      address owner,
      uint256 threshold
    ) = abi.decode(data, (uint256, uint256, bytes, address, uint256));

    PolyZDAO zDAO = PolyZDAO(
      createProxy(
        zDAOBase,
        abi.encodeWithSelector(
          PolyZDAO.__ZDAO_init.selector,
          IChildTunnel(this),
          zDAOId,
          owner,
          string(name),
          threshold
        )
      )
    );

    zDAOs[zDAOId] = zDAO;
    zDAOIds.push(zDAOId);

    emit DAOCreated(zDAOId, msg.sender, address(zDAO));

    return zDAO;
  }

  function _createProposal(bytes memory data) internal virtual {
    (
      uint256 messageType,
      uint256 zDAOId,
      uint256 proposalId,
      address createdBy,
      uint256 startTimestamp,
      uint256 endTimestamp,
      address token, // token on Etherem
      uint256 amount,
      bytes32 ipfs
    ) = abi.decode(
        data,
        (
          uint256,
          uint256,
          uint256,
          address,
          uint256,
          uint256,
          address,
          uint256,
          bytes32
        )
      );

    require(zDAOs[zDAOId].zDAOId() == zDAOId, "zDAO Not created yet");

    zDAOs[zDAOId].createProposal(
      proposalId,
      createdBy,
      startTimestamp,
      endTimestamp,
      IERC20Upgradeable(token),
      amount,
      ipfs
    );
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
      records[i] = zDAOs[zDAOIds[_startIndex + i]];
    }

    return records;
  }
}
