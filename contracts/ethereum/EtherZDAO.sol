// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {ZeroUpgradeable, SafeERC20Upgradeable, IERC20Upgradeable} from "../abstracts/ZeroUpgradeable.sol";
import {IRootTunnel, ITunnel} from "./interfaces/IRootTunnel.sol";
import {IEtherZDAO} from "./interfaces/IEtherZDAO.sol";
import {IEtherZDAOChef} from "./interfaces/IEtherZDAOChef.sol";
import {console} from "hardhat/console.sol";

contract EtherZDAO is ZeroUpgradeable, IEtherZDAO {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  ZDAOInfo public zDAOInfo;

  uint256 private lastProposalId;
  mapping(uint256 => Proposal) public proposals;
  uint256[] public proposalIds;

  IRootTunnel public rootTunnel;

  /* -------------------------------------------------------------------------- */
  /*                                  Modifiers                                 */
  /* -------------------------------------------------------------------------- */

  modifier onlyZDAOOwner() {
    require(msg.sender == zDAOInfo.owner, "Not a zDAO Owner");
    _;
  }

  modifier onlyRootTunnel() {
    require(msg.sender == address(rootTunnel), "Not a ZDAOChef");
    _;
  }

  modifier onlyValidTokenHolder() {
    require(
      zDAOInfo.token.balanceOf(msg.sender) >= zDAOInfo.amount,
      "Not a valid token holder"
    );
    _;
  }

  modifier isActiveDAO() {
    require(!zDAOInfo.destroyed, "Already destroyed");
    _;
  }

  function __ZDAO_init(
    address _rootTunnel,
    uint256 _zDAOId,
    address _zDAOOwner,
    IEtherZDAOChef.ZDAOConfig calldata _zDAOConfig
  ) public initializer {
    ZeroUpgradeable.initialize();

    rootTunnel = IRootTunnel(_rootTunnel);

    zDAOInfo = ZDAOInfo({
      zDAOId: _zDAOId,
      owner: _zDAOOwner,
      name: _zDAOConfig.name,
      gnosisSafe: _zDAOConfig.gnosisSafe,
      token: IERC20Upgradeable(_zDAOConfig.token),
      amount: _zDAOConfig.amount,
      minPeriod: _zDAOConfig.minPeriod,
      isRelativeMajority: _zDAOConfig.isRelativeMajority,
      threshold: _zDAOConfig.threshold,
      snapshot: block.number,
      destroyed: false
    });
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function setDestroyed(bool _destroyed) external override onlyRootTunnel {
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
    IERC20Upgradeable _token,
    uint256 _amount,
    bytes32 _ipfs
  ) external override isActiveDAO onlyValidTokenHolder {
    uint256 proposalId = _createProposal(
      _startTimestamp,
      _endTimestamp,
      _token,
      _amount,
      _ipfs
    );

    emit ProposalCreated(
      zDAOInfo.zDAOId,
      msg.sender,
      proposalId,
      _startTimestamp,
      _endTimestamp
    );

    // send proposal info to L2
    rootTunnel.sendMessageToChild(
      abi.encode(
        uint256(ITunnel.MessageType.CreateProposal),
        zDAOInfo.zDAOId,
        proposalId,
        _startTimestamp,
        _endTimestamp
      )
    );
  }

  function executeProposal(uint256 _proposalId) external override isActiveDAO {
    // TODO
    emit ProposalExecuted(zDAOInfo.zDAOId, _proposalId);
  }

  function setVoteResult(bytes calldata _data)
    external
    override
    onlyRootTunnel
  {
    (
      uint256 messageType,
      uint256 zDAOId,
      uint256 proposalId,
      uint256 yes,
      uint256 no
    ) = abi.decode(_data, (uint256, uint256, uint256, uint256, uint256));

    require(zDAOInfo.zDAOId == zDAOId);

    Proposal storage proposal = proposals[proposalId];
    require(proposal.proposalId == proposalId, "Invalid proposal");
    proposal.yes = yes;
    proposal.no = no;

    emit ProposalCollected(zDAOInfo.zDAOId, proposalId, yes, no);
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal Functions                             */
  /* -------------------------------------------------------------------------- */

  function _createProposal(
    uint256 _startTimestamp,
    uint256 _endTimestamp,
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
      yes: 0,
      no: 0,
      reserved: 0,
      ipfs: _ipfs,
      token: _token,
      amount: _amount,
      snapshot: block.number,
      state: ProposalState.Active
    });
    proposalIds.push(lastProposalId);

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
