// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {ZeroUpgradeable, SafeERC20Upgradeable, IERC20Upgradeable} from "../abstracts/ZeroUpgradeable.sol";
import {ITunnel} from "../interfaces/ITunnel.sol";
import {IEtherZDAO} from "./interfaces/IEtherZDAO.sol";
import {IEtherZDAOChef} from "./interfaces/IEtherZDAOChef.sol";
import {console} from "hardhat/console.sol";

contract EtherZDAO is ZeroUpgradeable, IEtherZDAO {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  ZDAOInfo public zDAOInfo;

  uint256 public lastProposalId;
  mapping(uint256 => Proposal) public proposals;
  uint256[] public proposalIds;

  address public zDAOChef;

  /* -------------------------------------------------------------------------- */
  /*                                  Modifiers                                 */
  /* -------------------------------------------------------------------------- */

  modifier onlyZDAOChef() {
    require(msg.sender == address(zDAOChef), "Not a ZDAOChef");
    _;
  }

  modifier onlyValidTokenHolder(address _holder) {
    require(
      IERC20Upgradeable(zDAOInfo.token).balanceOf(_holder) >= zDAOInfo.amount,
      "Not a valid token holder"
    );
    _;
  }

  modifier isActiveDAO() {
    require(!zDAOInfo.destroyed, "Already destroyed");
    _;
  }

  modifier onlyValidProposal(uint256 _proposalId) {
    require(_proposalId > 0 && _proposalId <= lastProposalId, "Invalid zDAO");
    _;
  }

  /* -------------------------------------------------------------------------- */
  /*                                 Initializer                                */
  /* -------------------------------------------------------------------------- */

  function __ZDAO_init(
    address _zDAOChef,
    uint256 _zDAOId,
    address _createdBy,
    IEtherZDAOChef.ZDAOConfig calldata _zDAOConfig
  ) public initializer {
    ZeroUpgradeable.__ZeroUpgradeable_init();

    zDAOChef = _zDAOChef;

    zDAOInfo = ZDAOInfo({
      zDAOId: _zDAOId,
      title: _zDAOConfig.title,
      createdBy: _createdBy,
      gnosisSafe: _zDAOConfig.gnosisSafe,
      token: _zDAOConfig.token,
      amount: _zDAOConfig.amount,
      isRelativeMajority: _zDAOConfig.isRelativeMajority,
      quorumVotes: _zDAOConfig.quorumVotes,
      snapshot: block.number,
      destroyed: false
    });
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function setDestroyed(bool _destroyed) external override onlyZDAOChef {
    zDAOInfo.destroyed = _destroyed;
  }

  function setGnosisSafe(address _gnosisSafe) external onlyZDAOChef {
    zDAOInfo.gnosisSafe = _gnosisSafe;
  }

  function setVotingToken(address _token, uint256 _amount)
    external
    onlyZDAOChef
  {
    zDAOInfo.token = _token;
    zDAOInfo.amount = _amount;
  }

  function createProposal(
    address _createdBy,
    uint256 _duration,
    address _target,
    uint256 _value,
    bytes calldata _data,
    string calldata _ipfs
  )
    external
    override
    onlyZDAOChef
    isActiveDAO
    onlyValidTokenHolder(_createdBy)
    returns (uint256)
  {
    uint256 proposalId = _createProposal(
      _createdBy,
      _duration,
      _target,
      _value,
      _data,
      _ipfs
    );

    return proposalId;
  }

  function cancelProposal(address, uint256 _proposalId)
    external
    override
    onlyZDAOChef
    isActiveDAO
    onlyValidProposal(_proposalId)
  {
    ProposalState state2 = this.state(_proposalId);
    require(
      state2 != ProposalState.Executed,
      "Can not cancel executed proposal"
    );
    require(state2 == ProposalState.Pending, "Not a pending proposal");

    proposals[_proposalId].canceled = true;
  }

  function executeProposal(address _executeBy, uint256 _proposalId)
    external
    override
    onlyZDAOChef
    isActiveDAO
    onlyValidProposal(_proposalId)
  {
    ProposalState state2 = this.state(_proposalId);
    require(state2 == ProposalState.Succeeded, "Not a succeeded proposal");

    Proposal storage proposal = proposals[_proposalId];

    (bool success, ) = proposal.target.call{value: proposal.value}(
      proposal.data
    );
    require(success, "Execution transaction reverted");
  }

  function setVoteResult(
    uint256 _proposalId,
    uint256 _yes,
    uint256 _no
  ) external override onlyZDAOChef onlyValidProposal(_proposalId) {
    Proposal storage proposal = proposals[_proposalId];
    require(proposal.proposalId == _proposalId, "Invalid proposal");

    ProposalState state2 = this.state(_proposalId);
    require(
      state2 == ProposalState.Failed || state2 == ProposalState.Succeeded,
      "Not time to set vote result"
    );
    require(proposal.yes + proposal.no == 0, "Already set vote result");

    proposal.yes = _yes;
    proposal.no = _no;
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal Functions                             */
  /* -------------------------------------------------------------------------- */

  function _createProposal(
    address _createdBy,
    uint256 _duration,
    address _target,
    uint256 _value,
    bytes memory _data,
    string memory _ipfs
  ) internal virtual returns (uint256 proposalId) {
    lastProposalId++;

    proposals[lastProposalId] = Proposal({
      proposalId: lastProposalId,
      createdBy: _createdBy,
      duration: _duration,
      yes: 0,
      no: 0,
      reserved: 0,
      ipfs: _ipfs,
      target: _target,
      value: _value,
      data: _data,
      snapshot: block.number,
      executed: false,
      canceled: false
    });
    proposalIds.push(lastProposalId);

    return lastProposalId;
  }

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function zDAOOwner() external view returns (address) {
    return zDAOInfo.createdBy;
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

  function state(uint256 _proposalId)
    external
    view
    override
    onlyValidProposal(_proposalId)
    returns (ProposalState)
  {
    Proposal storage proposal = proposals[_proposalId];
    if (proposal.canceled) {
      return ProposalState.Canceled;
    } else if (
      proposal.yes <= proposal.no || proposal.yes < zDAOInfo.quorumVotes
    ) {
      return ProposalState.Failed;
    } else if (
      proposal.yes >= proposal.no && proposal.yes >= zDAOInfo.quorumVotes
    ) {
      return ProposalState.Succeeded;
    } else if (proposal.executed) {
      return ProposalState.Executed;
    }

    return ProposalState.Pending;
  }
}
