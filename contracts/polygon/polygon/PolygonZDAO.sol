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
    address zDAOChef_,
    address staking_,
    uint256 zDAOId,
    uint256 duration,
    uint256 votingDelay,
    address token
  ) public initializer {
    ZeroUpgradeable.__ZeroUpgradeable_init();

    zDAOChef = zDAOChef_;
    staking = Staking(staking_);
    zDAOInfo = ZDAOInfo({
      zDAOId: zDAOId,
      duration: duration,
      votingDelay: votingDelay,
      token: token,
      snapshot: block.number,
      destroyed: false
    });
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function setDestroyed(bool destroyed_) external override onlyZDAOChef {
    zDAOInfo.destroyed = destroyed_;
  }

  function setStaking(address staking_) external override onlyZDAOChef {
    staking = Staking(staking_);
  }

  function updateToken(address token) external override onlyZDAOChef {
    zDAOInfo.token = token;
  }

  /**
   * @notice Create a proposal on Polygon with the information which was
   *     received from the Ethereum.
   *     EthereumZDAOChef only sends the proposal id created on Ethereum.
   * @dev Callable by PolygonZDAOChef, only available for active zDAO
   * @param proposalId Proposal unique id
   * @param numberOfChoices Number of choices
   * @param proposalCreated Block timestamp of current proposal creation
   */
  function createProposal(
    uint256 proposalId,
    uint256 numberOfChoices,
    uint256 proposalCreated
  ) external onlyZDAOChef isActiveDAO {
    require(
      proposalId > 0 && proposals[proposalId].proposalId == 0,
      "Proposal was already created"
    );

    uint256 startTimestamp = proposalCreated + zDAOInfo.votingDelay >
      block.timestamp
      ? proposalCreated + zDAOInfo.votingDelay
      : block.timestamp;

    _createProposal(
      proposalId,
      numberOfChoices,
      startTimestamp,
      startTimestamp + zDAOInfo.duration
    );
  }

  /**
   * @notice Mark a proposal as canceled state.
   *     Once the proposal is canceled on Ethereum, that is synchronized to
   *     Polygon. The proposal should be active prior to cancel.
   * @dev Callable by PolygonZDAOChef, only available for active zDAO
   * @param proposalId Proposal unique id
   */
  function cancelProposal(uint256 proposalId)
    external
    onlyZDAOChef
    isActiveDAO
    onlyValidProposal(proposalId)
  {
    require(
      !proposals[proposalId].canceled && !proposals[proposalId].calculated,
      "Already canceled or calculateed proposal"
    );
    _cancelProposal(proposalId);
  }

  /**
   * @notice Calculate a proposal, the proposal should be ended and not canceled
   *     Anyone can calculate a proposal if it ends, and the transaction of
   *     proposal calculation will be sent to Ethereum.
   * @dev Callable by PolygonZDAOChef, only available for active zDAO
   * @param proposalId Proposal unique id
   */
  function calculateProposal(uint256 proposalId)
    external
    onlyZDAOChef
    isActiveDAO
    onlyValidProposal(proposalId)
    returns (uint256 voters, uint256[] memory votes)
  {
    Proposal storage proposal = proposals[proposalId];
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
   * @param proposalId Proposal unique id
   * @param voter Voter address
   * @param choice Voter choice, starting from 1
   */
  function vote(
    uint256 proposalId,
    address voter,
    uint256 choice
  )
    external
    onlyZDAOChef
    isActiveDAO
    onlyValidProposal(proposalId)
    returns (uint256)
  {
    require(
      choice > 0 && choice <= proposals[proposalId].numberOfChoices,
      "Invalid choice"
    );
    require(
      _canVote(proposalId, voter, zDAOInfo.token),
      "Not valid for voting"
    );

    return _vote(proposalId, voter, zDAOInfo.token, choice);
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal Functions                             */
  /* -------------------------------------------------------------------------- */

  function _isProposalOpen(Proposal storage proposal)
    internal
    view
    virtual
    returns (bool)
  {
    return
      block.timestamp >= proposal.startTimestamp &&
      block.timestamp < proposal.endTimestamp &&
      !proposal.canceled;
  }

  function _isProposalClosed(Proposal storage proposal)
    internal
    view
    virtual
    returns (bool)
  {
    return block.timestamp > proposal.endTimestamp;
  }

  function _createProposal(
    uint256 proposalId,
    uint256 numberOfChoices,
    uint256 startTimestamp,
    uint256 endTimestamp
  ) internal virtual {
    require(proposals[proposalId].proposalId == 0, "Already proposal created");
    proposals[proposalId] = Proposal({
      proposalId: proposalId,
      numberOfChoices: numberOfChoices,
      startTimestamp: startTimestamp,
      endTimestamp: endTimestamp,
      voters: 0,
      snapshot: block.number,
      calculated: false,
      canceled: false,
      votes: new uint256[](numberOfChoices)
    });
    proposalIds.push(proposalId);
  }

  function _cancelProposal(uint256 proposalId) internal virtual {
    proposals[proposalId].canceled = true;
  }

  function _canVote(
    uint256 proposalId,
    address voter,
    address token
  ) internal view virtual returns (bool) {
    Proposal storage proposal = proposals[proposalId];
    if (proposal.proposalId != proposalId || !_isProposalOpen(proposal)) {
      return false;
    }
    return staking.pastStakingPower(voter, token, proposal.snapshot) > 0;
  }

  function _vote(
    uint256 proposalId,
    address voter,
    address token,
    uint256 choice
  ) internal virtual returns (uint256) {
    Proposal storage proposal = proposals[proposalId];
    ProposalVotes storage votes = proposalVotes[proposalId];
    uint256 last = votes.votes[voter].choice;

    uint256 vp = _votingPower(proposalId, voter, token);

    if (last == 0) {
      // if not voted yet
      votes.voters.push(voter);
    } else {
      proposal.votes[last - 1] -= vp;
    }

    votes.votes[voter].voter = voter;
    votes.votes[voter].choice = choice;
    votes.votes[voter].votes = vp;

    proposal.votes[choice - 1] += vp;
    proposal.voters = votes.voters.length;

    return vp;
  }

  function _canCalculateProposal(uint256 proposalId)
    internal
    view
    virtual
    returns (bool)
  {
    Proposal storage proposal = proposals[proposalId];
    return proposal.proposalId == proposalId && _isProposalClosed(proposal);
  }

  function _votingPower(
    uint256 proposalId,
    address voter,
    address token
  ) internal view virtual returns (uint256) {
    return
      staking.pastStakingPower(voter, token, proposals[proposalId].snapshot);
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

  function getProposalById(uint256 proposalId)
    external
    view
    returns (Proposal memory)
  {
    return proposals[proposalId];
  }

  function listProposals(uint256 startIndex, uint256 count)
    external
    view
    override
    returns (Proposal[] memory records)
  {
    uint256 numRecords = count;
    if (proposalIds.length <= startIndex) {
      numRecords = 0;
    } else if (numRecords > (proposalIds.length - startIndex)) {
      numRecords = proposalIds.length - startIndex;
    }

    records = new Proposal[](numRecords);

    for (uint256 i = 0; i < numRecords; ++i) {
      records[i] = proposals[proposalIds[startIndex + i]];
    }

    return records;
  }

  function state(uint256 proposalId)
    external
    view
    override
    returns (ProposalState)
  {
    Proposal storage proposal = proposals[proposalId];
    if (proposal.canceled) {
      return ProposalState.Canceled;
    } else if (block.timestamp <= proposal.startTimestamp) {
      return ProposalState.Pending;
    } else if (block.timestamp <= proposal.endTimestamp) {
      return ProposalState.Active;
    } else if (proposal.calculated) {
      return ProposalState.Closed;
    }
    return ProposalState.AwaitingCalculation;
  }

  function votesResultOfProposal(uint256 proposalId)
    external
    view
    override
    returns (uint256 voters, uint256[] memory votes)
  {
    Proposal storage proposal = proposals[proposalId];

    voters = proposal.voters;
    votes = new uint256[](proposal.votes.length);
    for (uint256 i = 0; i < proposal.votes.length; i++) {
      votes[i] = proposal.votes[i];
    }
  }

  function canVote(uint256 proposalId, address voter)
    external
    view
    override
    returns (bool)
  {
    return _canVote(proposalId, voter, zDAOInfo.token);
  }

  function canCalculateProposal(uint256 proposalId)
    external
    view
    override
    returns (bool)
  {
    return _canCalculateProposal(proposalId);
  }

  function choiceOfVoter(uint256 proposalId, address voter)
    external
    view
    override
    returns (uint256)
  {
    return proposalVotes[proposalId].votes[voter].choice;
  }

  function votingPowerOfVoter(uint256 proposalId, address voter)
    external
    view
    override
    returns (uint256)
  {
    return _votingPower(proposalId, voter, zDAOInfo.token);
  }

  function listVoters(
    uint256 proposalId,
    uint256 startIndex,
    uint256 count
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
    ProposalVotes storage singleProposalVotes = proposalVotes[proposalId];

    uint256 numRecords = count;
    if (singleProposalVotes.voters.length <= startIndex) {
      numRecords = 0;
    } else if (numRecords > (singleProposalVotes.voters.length - startIndex)) {
      numRecords = singleProposalVotes.voters.length - startIndex;
    }

    voters = new address[](numRecords);
    choices = new uint256[](numRecords);
    votes = new uint256[](numRecords);

    address voter;
    for (uint256 i = 0; i < numRecords; ++i) {
      voter = singleProposalVotes.voters[startIndex + i];
      voters[i] = voter;
      choices[i] = uint256(singleProposalVotes.votes[voter].choice);
      votes[i] = singleProposalVotes.votes[voter].votes;
    }
  }
}
