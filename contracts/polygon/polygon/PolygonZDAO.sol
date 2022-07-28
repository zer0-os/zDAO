// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {ZeroUpgradeable, IERC20Upgradeable} from "../../abstracts/ZeroUpgradeable.sol";
import {IPolygonZDAO} from "./interfaces/IPolygonZDAO.sol";
import {Staking} from "./Staking.sol";

contract PolygonZDAO is ZeroUpgradeable, IPolygonZDAO {
  address public zDAOChef;
  Staking public staking;

  ZDAOInfo public zDAOInfo;

  // <proposal id, Proposal>
  mapping(uint256 => Proposal) public proposals;

  // <proposal id, voter address, choice>
  mapping(uint256 => ProposalVotes) private proposalVotes;

  // list of proposal ids
  uint256[] public proposalIds;

  /* -------------------------------------------------------------------------- */
  /*                                  Modifiers                                 */
  /* -------------------------------------------------------------------------- */

  modifier onlyZDAOChef() {
    require(msg.sender == zDAOChef, "Not a ZDAOChef");
    _;
  }

  modifier isActiveDAO() {
    require(!zDAOInfo.destroyed, "Already destroyed");
    _;
  }

  modifier onlyValidProposal(uint256 _proposalId) {
    require(
      proposals[_proposalId].proposalId == _proposalId,
      "Invalid proposal"
    );
    _;
  }

  /* -------------------------------------------------------------------------- */
  /*                                 Initializer                                */
  /* -------------------------------------------------------------------------- */

  function __ZDAO_init(
    address _zDAOChef,
    address _staking,
    uint256 _zDAOId,
    uint256 _duration,
    address _token
  ) public initializer {
    ZeroUpgradeable.__ZeroUpgradeable_init();

    zDAOChef = _zDAOChef;
    staking = Staking(_staking);
    zDAOInfo = ZDAOInfo({
      zDAOId: _zDAOId,
      duration: _duration,
      token: _token,
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

  function setStaking(address _staking) external override onlyZDAOChef {
    staking = Staking(_staking);
  }

  function updateToken(address _token) external override onlyZDAOChef {
    zDAOInfo.token = _token;
  }

  /**
   * @notice Create a proposal on Polygon with the information which was
   *     received from the Ethereum.
   *     EthereumZDAOChef only sends the proposal id created on Ethereum.
   * @dev Callable by PolygonZDAOChef, only available for active zDAO
   * @param _proposalId Proposal unique id
   * @param _numberOfChoices Number of choices
   * @param _startTimestamp Current block timestamp
   */
  function createProposal(
    uint256 _proposalId,
    uint256 _numberOfChoices,
    uint256 _startTimestamp
  ) external onlyZDAOChef isActiveDAO {
    require(
      _proposalId > 0 && proposals[_proposalId].proposalId == 0,
      "Proposal was already created"
    );

    _createProposal(
      _proposalId,
      _numberOfChoices,
      _startTimestamp,
      _startTimestamp + zDAOInfo.duration
    );
  }

  /**
   * @notice Mark a proposal as canceled state.
   *     Once the proposal is canceled on Ethereum, that is synchronized to
   *     Polygon. The proposal should be active prior to cancel.
   * @dev Callable by PolygonZDAOChef, only available for active zDAO
   * @param _proposalId Proposal unique id
   */
  function cancelProposal(uint256 _proposalId)
    external
    onlyZDAOChef
    isActiveDAO
    onlyValidProposal(_proposalId)
  {
    require(
      !proposals[_proposalId].canceled && !proposals[_proposalId].calculated,
      "Already canceled or calculateed proposal"
    );
    _cancelProposal(_proposalId);
  }

  /**
   * @notice Mark a proposal as executed state, executing a proposal is
   *     executed on Ethereum and synchronized to Polygon to update the state.
   * @dev Callable by PolygonZDAOChef, only available for active zDAO
   * @param _proposalId Proposal unique id
   */
  function executeProposal(uint256 _proposalId)
    external
    onlyZDAOChef
    isActiveDAO
    onlyValidProposal(_proposalId)
  {
    require(
      !proposals[_proposalId].canceled && proposals[_proposalId].calculated,
      "Not a valid proposal"
    );
    _executeProposal(_proposalId);
  }

  /**
   * @notice Calculate a proposal, the proposal should be ended and not canceled
   *     Anyone can calculate a proposal if it ends, and the transaction of
   *     proposal calculation will be sent to Ethereum.
   * @dev Callable by PolygonZDAOChef, only available for active zDAO
   * @param _proposalId Proposal unique id
   */
  function calculateProposal(uint256 _proposalId)
    external
    onlyZDAOChef
    isActiveDAO
    onlyValidProposal(_proposalId)
    returns (uint256 voters, uint256[] memory votes)
  {
    Proposal storage proposal = proposals[_proposalId];
    require(
      !proposal.canceled &&
        !proposal.calculated &&
        block.timestamp > proposal.endTimestamp, // proposal has already ended
      "Not a valid proposal"
    );

    voters = proposal.voters;
    votes = new uint256[](proposal.votes.length);
    for (uint256 i = 0; i < proposal.votes.length; i++) {
      votes[i] = proposal.votes[i];
    }

    proposal.calculated = true;
  }

  /**
   * @notice Cast a vote with user's choice. Anyone who have voting power can
   *     participate a voting.
   * @dev Callable by PolygonZDAOChef, only available for active zDAO and valid
   *     proposal
   * @param _proposalId Proposal unique id
   * @param _voter Voter address
   * @param _choice Voter choice, starting from 1
   */
  function vote(
    uint256 _proposalId,
    address _voter,
    uint256 _choice
  ) external onlyZDAOChef isActiveDAO onlyValidProposal(_proposalId) {
    require(
      _choice > 0 && _choice <= proposals[_proposalId].numberOfChoices,
      "Invalid choice"
    );
    require(
      _canVote(_proposalId, _voter, zDAOInfo.token),
      "Not valid for voting"
    );

    _vote(_proposalId, _voter, zDAOInfo.token, _choice);
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal Functions                             */
  /* -------------------------------------------------------------------------- */

  function _isProposalOpen(Proposal storage _proposal)
    internal
    view
    virtual
    returns (bool)
  {
    return
      block.timestamp >= _proposal.startTimestamp &&
      block.timestamp < _proposal.endTimestamp &&
      !_proposal.canceled;
  }

  function _isProposalClosed(Proposal storage _proposal)
    internal
    view
    virtual
    returns (bool)
  {
    return block.timestamp > _proposal.endTimestamp;
  }

  function _createProposal(
    uint256 _proposalId,
    uint256 _numberOfChoices,
    uint256 _startTimestamp,
    uint256 _endTimestamp
  ) internal virtual {
    require(proposals[_proposalId].proposalId == 0, "Already proposal created");
    proposals[_proposalId] = Proposal({
      proposalId: _proposalId,
      numberOfChoices: _numberOfChoices,
      startTimestamp: _startTimestamp,
      endTimestamp: _endTimestamp,
      voters: 0,
      snapshot: block.number,
      calculated: false,
      executed: false,
      canceled: false,
      votes: new uint256[](_numberOfChoices)
    });
    proposalIds.push(_proposalId);
  }

  function _cancelProposal(uint256 _proposalId) internal virtual {
    proposals[_proposalId].canceled = true;
  }

  function _executeProposal(uint256 _proposalId) internal virtual {
    proposals[_proposalId].executed = true;
  }

  function _canVote(
    uint256 _proposalId,
    address _voter,
    address _token
  ) internal view virtual returns (bool) {
    Proposal storage proposal = proposals[_proposalId];
    if (proposal.proposalId != _proposalId || !_isProposalOpen(proposal)) {
      return false;
    }
    return staking.pastStakingPower(_voter, _token, proposal.snapshot) > 0;
  }

  function _vote(
    uint256 _proposalId,
    address _voter,
    address _token,
    uint256 _choice
  ) internal virtual {
    Proposal storage proposal = proposals[_proposalId];
    ProposalVotes storage votes = proposalVotes[_proposalId];
    uint256 last = votes.votes[_voter].choice;

    uint256 vp = _votingPower(_proposalId, _voter, _token);

    if (last == 0) {
      // if not voted yet
      votes.voters.push(_voter);
    } else {
      proposal.votes[last - 1] -= vp;
    }

    votes.votes[_voter].voter = _voter;
    votes.votes[_voter].choice = _choice;
    votes.votes[_voter].votes = vp;

    proposal.votes[_choice - 1] += vp;
    proposal.voters = votes.voters.length;
  }

  function _canCalculateProposal(uint256 _proposalId)
    internal
    view
    virtual
    returns (bool)
  {
    Proposal storage proposal = proposals[_proposalId];
    return proposal.proposalId == _proposalId && _isProposalClosed(proposal);
  }

  function _votingPower(
    uint256 _proposalId,
    address _voter,
    address _token
  ) internal view virtual returns (uint256) {
    return
      staking.pastStakingPower(_voter, _token, proposals[_proposalId].snapshot);
  }

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function getZDAOId() external view override returns (uint256) {
    return zDAOInfo.zDAOId;
  }

  function getZDAOInfo() external view override returns (ZDAOInfo memory) {
    return zDAOInfo;
  }

  function destroyed() external view override returns (bool) {
    return zDAOInfo.destroyed;
  }

  function numberOfProposals() external view override returns (uint256) {
    return proposalIds.length;
  }

  function getProposalById(uint256 _proposalId)
    external
    view
    returns (Proposal memory)
  {
    return proposals[_proposalId];
  }

  function listProposals(uint256 _startIndex, uint256 _count)
    external
    view
    override
    returns (Proposal[] memory records)
  {
    uint256 numRecords = _count;
    if (proposalIds.length <= _startIndex) {
      numRecords = 0;
    } else if (numRecords > (proposalIds.length - _startIndex)) {
      numRecords = proposalIds.length - _startIndex;
    }

    records = new Proposal[](numRecords);

    for (uint256 i = 0; i < numRecords; ++i) {
      records[i] = proposals[proposalIds[_startIndex + i]];
    }

    return records;
  }

  function state(uint256 _proposalId)
    external
    view
    override
    returns (ProposalState)
  {
    Proposal storage proposal = proposals[_proposalId];
    if (proposal.canceled) {
      return ProposalState.Canceled;
    } else if (block.timestamp <= proposal.startTimestamp) {
      return ProposalState.Pending;
    } else if (block.timestamp <= proposal.endTimestamp) {
      return ProposalState.Active;
    } else if (proposal.executed) {
      return ProposalState.Executed;
    } else if (proposal.calculated) {
      return ProposalState.Calculated;
    }
    return ProposalState.Calculating;
  }

  function votesResultOfProposal(uint256 _proposalId)
    external
    view
    override
    returns (uint256 voters, uint256[] memory votes)
  {
    Proposal storage proposal = proposals[_proposalId];

    voters = proposal.voters;
    votes = new uint256[](proposal.votes.length);
    for (uint256 i = 0; i < proposal.votes.length; i++) {
      votes[i] = proposal.votes[i];
    }
  }

  function canVote(uint256 _proposalId, address _voter)
    external
    view
    override
    returns (bool)
  {
    return _canVote(_proposalId, _voter, zDAOInfo.token);
  }

  function canCalculateProposal(uint256 _proposalId)
    external
    view
    override
    returns (bool)
  {
    return _canCalculateProposal(_proposalId);
  }

  function choiceOfVoter(uint256 _proposalId, address _voter)
    external
    view
    override
    returns (uint256)
  {
    return proposalVotes[_proposalId].votes[_voter].choice;
  }

  function votingPowerOfVoter(uint256 _proposalId, address _voter)
    external
    view
    override
    returns (uint256)
  {
    return _votingPower(_proposalId, _voter, zDAOInfo.token);
  }

  function listVoters(
    uint256 _proposalId,
    uint256 _startIndex,
    uint256 _count
  )
    external
    view
    override
    returns (
      address[] memory voters,
      uint256[] memory choices,
      uint256[] memory votes
    )
  {
    ProposalVotes storage singleProposalVotes = proposalVotes[_proposalId];

    uint256 numRecords = _count;
    if (singleProposalVotes.voters.length <= _startIndex) {
      numRecords = 0;
    } else if (numRecords > (singleProposalVotes.voters.length - _startIndex)) {
      numRecords = singleProposalVotes.voters.length - _startIndex;
    }

    voters = new address[](numRecords);
    choices = new uint256[](numRecords);
    votes = new uint256[](numRecords);

    address voter;
    for (uint256 i = 0; i < numRecords; ++i) {
      voter = singleProposalVotes.voters[_startIndex + i];
      voters[i] = voter;
      choices[i] = uint256(singleProposalVotes.votes[voter].choice);
      votes[i] = singleProposalVotes.votes[voter].votes;
    }
  }
}
