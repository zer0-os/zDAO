// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "../abstracts/ZeroUpgradeable.sol";
import "./interfaces/IRootTunnel.sol";
import "./interfaces/IEtherZDAO.sol";
import "./interfaces/IEtherZDAOChef.sol";
import "hardhat/console.sol";

contract EtherZDAO is ZeroUpgradeable, IEtherZDAO {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  ZDAOInfo public zDAOInfo;

  uint256 private lastProposalId;
  mapping(uint256 => Proposal) public proposals;
  IRootTunnel public rootTunnel;

  /* -------------------------------------------------------------------------- */
  /*                                  Modifiers                                 */
  /* -------------------------------------------------------------------------- */
  modifier onlyZDAOOwner() {
    require(msg.sender == zDAOInfo.owner, "Not a zDAO Owner");
    _;
  }

  modifier onlyValidTokenHolder() {
    require(
      zDAOInfo.token.balanceOf(msg.sender) >= zDAOInfo.amount,
      "Not a valid token holder"
    );
    _;
  }

  function __ZDAO_init(
    IRootTunnel _rootTunnel,
    uint256 _zDAOId,
    address _zDAOOwner,
    IEtherZDAOChef.ZDAOConfig calldata _zDAOConfig
  ) external initializer {
    ZeroUpgradeable.initialize();

    rootTunnel = _rootTunnel;

    zDAOInfo = ZDAOInfo({
      zDAOId: _zDAOId,
      owner: _zDAOOwner,
      name: _zDAOConfig.name,
      gnosisSafe: _zDAOConfig.gnosisSafe,
      token: IERC20Upgradeable(_zDAOConfig.token),
      amount: _zDAOConfig.amount,
      minPeriod: _zDAOConfig.minPeriod,
      threshold: _zDAOConfig.threshold,
      destroyed: false
    });
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function setDestroyed(bool _destroyed) external override onlyOwner {
    zDAOInfo.destroyed = _destroyed;
  }

  function setGnosisSafe(address _gnosisSafe) external onlyZDAOOwner {
    zDAOInfo.gnosisSafe = _gnosisSafe;
  }

  function setVotingToken(IERC20Upgradeable _token, uint256 _amount)
    external
    onlyZDAOOwner
  {
    zDAOInfo.token = _token;
    zDAOInfo.amount = _amount;
  }

  function createProposal(
    uint256 _startTimestamp,
    uint256 _endTimestamp,
    bool _isRelativeMajority,
    IERC20Upgradeable _token,
    uint256 _amount,
    bytes32 _ipfs
  ) external override onlyValidTokenHolder {
    uint256 proposalId = _createProposal(
      _startTimestamp,
      _endTimestamp,
      _isRelativeMajority,
      _token,
      _amount,
      _ipfs
    );

    emit ProposalCreated(
      zDAOInfo.zDAOId,
      msg.sender,
      proposalId,
      _startTimestamp,
      _endTimestamp,
      _isRelativeMajority
    );
  }

  function executeProposal(uint256 _proposalId) external override {
    // TODO
    emit ProposalExecuted(zDAOInfo.zDAOId, _proposalId);
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal Functions                             */
  /* -------------------------------------------------------------------------- */

  function _createProposal(
    uint256 _startTimestamp,
    uint256 _endTimestamp,
    bool _isRelativeMajority,
    IERC20Upgradeable _token,
    uint256 _amount,
    bytes32 _ipfs
  ) internal virtual returns (uint256 proposalId) {
    lastProposalId++;

    proposals[lastProposalId] = Proposal({
      proposalId: lastProposalId,
      createdBy: msg.sender,
      startTimestamp: _startTimestamp,
      endTimestamp: _endTimestamp,
      threshold: zDAOInfo.threshold,
      yes: 0,
      no: 0,
      reserved: 0,
      isRelativeMajority: _isRelativeMajority,
      ipfs: _ipfs,
      token: _token,
      amount: _amount,
      state: ProposalState.Active
    });
    return lastProposalId;
  }

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function zDAOOwner() external view returns (address) {
    return zDAOInfo.owner;
  }

  function destroyed() external view returns (bool) {
    return zDAOInfo.destroyed;
  }

  function numberOfProposals() external view override returns (uint256) {
    return lastProposalId;
  }

  function listProposals(uint256 _startIndex, uint256 _endIndex)
    external
    view
    override
    returns (Proposal[] memory)
  {
    require(_startIndex > 0, "should start index > 0");
    require(_startIndex <= _endIndex, "should start index <= end");
    require(_startIndex <= lastProposalId, "should start index <= length");
    require(_endIndex <= lastProposalId, "should end index <= length");

    uint256 numRecords = _endIndex - _startIndex + 1;
    Proposal[] memory records = new Proposal[](numRecords);

    for (uint256 i = 0; i < numRecords; ++i) {
      records[i] = proposals[_startIndex + i];
    }

    return records;
  }
}
