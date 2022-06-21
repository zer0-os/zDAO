// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {ZeroUpgradeable, SafeERC20Upgradeable, IERC20Upgradeable} from "../../abstracts/ZeroUpgradeable.sol";
import {ITunnel} from "../../interfaces/ITunnel.sol";
import {IEthereumZDAO} from "./interfaces/IEthereumZDAO.sol";
import {IEthereumZDAOChef} from "./interfaces/IEthereumZDAOChef.sol";

contract EthereumZDAO is ZeroUpgradeable, IEthereumZDAO {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  uint256 public constant divisionConstant = 10000;

  ZDAOInfo private daoInfo;

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
      IERC20Upgradeable(daoInfo.token).balanceOf(_holder) >= daoInfo.amount,
      "Not a valid token holder"
    );
    _;
  }

  modifier isActiveDAO() {
    require(!daoInfo.destroyed, "Already destroyed");
    _;
  }

  modifier onlyValidProposal(uint256 _proposalId) {
    require(_proposalId > 0 && _proposalId <= lastProposalId, "Invalid zDAO");
    _;
  }

  /* -------------------------------------------------------------------------- */
  /*                                 Initializer                                */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Initializer function
   * @param _zDAOChef Address to EthereumZDAOChef contract
   * @param _zDAOId Unique id for current zDAO
   * @param _gnosisSafe Address to Gnosis Safe
   * @param _createdBy Address to zDAO owner
   * @param _zDAOConfig Structure of zDAO configuration
   */
  function __ZDAO_init(
    address _zDAOChef,
    uint256 _zDAOId,
    address _gnosisSafe,
    address _createdBy,
    IEthereumZDAOChef.ZDAOConfig calldata _zDAOConfig
  ) public initializer {
    ZeroUpgradeable.__ZeroUpgradeable_init();

    zDAOChef = _zDAOChef;

    daoInfo = ZDAOInfo({
      zDAOId: _zDAOId,
      createdBy: _createdBy,
      gnosisSafe: _gnosisSafe,
      token: _zDAOConfig.token,
      amount: _zDAOConfig.amount,
      duration: _zDAOConfig.duration,
      votingThreshold: _zDAOConfig.votingThreshold,
      minimumVotingParticipants: _zDAOConfig.minimumVotingParticipants,
      minimumTotalVotingTokens: _zDAOConfig.minimumTotalVotingTokens,
      snapshot: block.number,
      isRelativeMajority: _zDAOConfig.isRelativeMajority,
      destroyed: false
    });
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Destroy the zDAO
   * @dev Callable by EthereumZDAOChef
   * @param _destroyed Flag marking whether zDAO has been destroyed
   */
  function setDestroyed(bool _destroyed) external override onlyZDAOChef {
    daoInfo.destroyed = _destroyed;
  }

  /**
   * @notice Set Gnosis Safe address, Voting Token and minimum holding token amount
   * @dev Callable by EthereumZDAOChef, only available for active zDAO
   * @param _gnosisSafe Address to Gnosis Safe wallet
   * @param _token Address to Voting Token
   * @param _amount Minimum number of tokens required to become proposal creator
   */
  function modifyZDAO(
    address _gnosisSafe,
    address _token,
    uint256 _amount
  ) external override isActiveDAO onlyZDAOChef {
    daoInfo.gnosisSafe = _gnosisSafe;
    daoInfo.token = _token;
    daoInfo.amount = _amount;
  }

  /**
   * @notice Create a proposal with the IPFS which contains proposal meta data
   * @dev Callable by EthereumZDAOChef, only available for active zDAO
   * @param _createdBy Address to the proposal owner
   * @param _ipfs IPFS hash which contains proposal meta data e.g. body text
   */
  function createProposal(address _createdBy, string calldata _ipfs)
    external
    override
    onlyZDAOChef
    isActiveDAO
    onlyValidTokenHolder(_createdBy)
    returns (uint256)
  {
    uint256 proposalId = _createProposal(_createdBy, _ipfs);

    return proposalId;
  }

  /**
   * @notice Cancel a proposal, proposal owner can only cancel pending proposal
   *      It means that proposal is still synchronizing to Polygon or active.
   * @dev Callable by EthereumZDAOChef, only available for active zDAO and valid
   *      proposal
   * @param _cancelBy Address to user who is going to cancel proposal
   * @param _proposalId Proposal unique id to cancel
   */
  function cancelProposal(address _cancelBy, uint256 _proposalId)
    external
    override
    onlyZDAOChef
    isActiveDAO
    onlyValidProposal(_proposalId)
  {
    require(
      proposals[_proposalId].createdBy == _cancelBy,
      "Not a proposal creator"
    );
    ProposalState state2 = this.state(_proposalId);
    require(state2 == ProposalState.Pending, "Not a pending proposal");

    proposals[_proposalId].canceled = true;
  }

  /**
   * @notice Execute proposal, only granted owner can execute proposal
   *     Execute proposal means transfer assets from Gnosis Safe to certain
   *     wallet address, once owner propose transaction on Gnosis Safe,
   *     then the proposal can be flaged by executed state
   * @dev Callable by EthereumZDAOChef, only available for active zDAO and valid
   *     proposal
   * @param _executeBy Address to wallet who is going to executed
   * @param _proposalId Proposal unique id to execute
   */
  function executeProposal(address _executeBy, uint256 _proposalId)
    external
    override
    onlyZDAOChef
    isActiveDAO
    onlyValidProposal(_proposalId)
  {
    ProposalState state2 = this.state(_proposalId);
    require(state2 == ProposalState.Succeeded, "Not a succeeded proposal");

    proposals[_proposalId].executed = true;
  }

  /**
   * @notice Calculate proposal, anybody can calculate proposal.
   *     Through proposal calculation, zDAO can receive the final voting result
   *     from the Polygon. This function should be executed only when zDAOChef
   *     receives the CalculateProposal event from the Polygon.
   *     Proposal state is pending state until proposal calculation.
   * @dev Callable by EthereumZDAOchef, only available for active zDAO and valid
   *     proposal
   * @param _proposalId Proposal unique id to execute
   * @param _voters Number of voters who participated in
   * @param _yes Number of all the casted votes in favor of this proposal
   * @param _no Number of all the casted votes in opposition to this proposal
   */
  function calculateProposal(
    uint256 _proposalId,
    uint256 _voters,
    uint256 _yes,
    uint256 _no
  ) external override onlyZDAOChef onlyValidProposal(_proposalId) {
    Proposal storage proposal = proposals[_proposalId];
    require(!proposal.calculated, "Already calculated proposal");

    ProposalState state2 = this.state(_proposalId);
    require(state2 == ProposalState.Pending, "Not a pending proposal");

    proposal.voters = _voters;
    proposal.yes = _yes;
    proposal.no = _no;

    proposals[_proposalId].calculated = true;
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal Functions                             */
  /* -------------------------------------------------------------------------- */

  function _createProposal(address _createdBy, string memory _ipfs)
    internal
    virtual
    returns (uint256 proposalId)
  {
    lastProposalId++;

    proposals[lastProposalId] = Proposal({
      proposalId: lastProposalId,
      createdBy: _createdBy,
      created: block.timestamp,
      yes: 0,
      no: 0,
      voters: 0,
      ipfs: _ipfs,
      snapshot: block.number,
      calculated: false,
      executed: false,
      canceled: false
    });
    proposalIds.push(lastProposalId);

    return lastProposalId;
  }

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function zDAOInfo() external view override returns (ZDAOInfo memory) {
    return daoInfo;
  }

  function zDAOOwner() external view returns (address) {
    return daoInfo.createdBy;
  }

  function destroyed() external view returns (bool) {
    return daoInfo.destroyed;
  }

  function numberOfProposals() external view override returns (uint256) {
    return lastProposalId;
  }

  function listProposals(uint256 _startIndex, uint256 _count)
    external
    view
    override
    returns (Proposal[] memory records)
  {
    uint256 numRecords = _count;
    if (numRecords > (lastProposalId - _startIndex)) {
      numRecords = lastProposalId - _startIndex;
    }

    records = new Proposal[](numRecords);

    for (uint256 i = 0; i < numRecords; ++i) {
      records[i] = proposals[_startIndex + i + 1];
    }

    return records;
  }

  /**
   * @notice Return the proposal state
   *     Canceled if already canceled
   *     Executed if already executed
   *     Pending if the proposal is synchronizing to Polygon or already started,
   *       but not calculated yet
   *     The number of participated voters should be exceed minimum voting
   *     participants, and total votes should also be exceed minimum total
   *     voting tokens.
   *     The voting result is determined by percentage, in which Yes votes takes
   *     In relative majority, calculate the percentage in the total sum of yes
   *     no votes. On the other hand, in absolute majority, calculate in total
   *     supply.
   */
  function state(uint256 _proposalId)
    external
    view
    override
    returns (ProposalState)
  {
    Proposal storage proposal = proposals[_proposalId];
    if (proposal.canceled) {
      return ProposalState.Canceled;
    } else if (proposal.executed) {
      return ProposalState.Executed;
    } else if (!proposal.calculated) {
      return ProposalState.Pending;
    }

    // Check quorum
    if (
      proposal.voters < daoInfo.minimumVotingParticipants ||
      proposal.yes + proposal.no < daoInfo.minimumTotalVotingTokens
    ) {
      return ProposalState.Failed;
    }
    // If relative majority, the denominator should be sum of yes and no votes
    if (
      daoInfo.isRelativeMajority &&
      (proposal.yes + proposal.no > 0) &&
      ((proposal.yes * divisionConstant) / (proposal.yes + proposal.no) >=
        daoInfo.votingThreshold)
    ) {
      return ProposalState.Succeeded;
    }
    // If absolute majority, the denominator should be total supply
    uint256 totalSupply = IERC20Upgradeable(daoInfo.token).totalSupply();
    if (
      !daoInfo.isRelativeMajority &&
      totalSupply > 0 &&
      (proposal.yes * divisionConstant) / totalSupply >= daoInfo.votingThreshold
    ) {
      return ProposalState.Succeeded;
    }

    return ProposalState.Failed;
  }
}
