// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {ZeroUpgradeable, IERC20Upgradeable} from "../abstracts/ZeroUpgradeable.sol";
import {IPolyZDAO} from "./interfaces/IPolyZDAO.sol";
import {Staking} from "./Staking.sol";

contract PolyZDAO is ZeroUpgradeable, IPolyZDAO {
  address public zDAOChef;
  Staking public staking;

  ZDAOInfo public zDAOInfo;

  // <proposal id, Proposal>
  mapping(uint256 => Proposal) public proposals;

  // <proposal id, voter address, VoterChoice>
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
    uint256 _duration
  ) public initializer {
    ZeroUpgradeable.__ZeroUpgradeable_init();

    zDAOChef = _zDAOChef;
    staking = Staking(_staking);
    zDAOInfo = ZDAOInfo({
      zDAOId: _zDAOId,
      duration: _duration,
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

  function createProposal(
    uint256 _proposalId,
    uint256 _startTimestamp
  ) external onlyZDAOChef isActiveDAO {
    require(
      _proposalId > 0 && proposals[_proposalId].proposalId == 0,
      "Proposal was already created"
    );

    _createProposal(_proposalId, _startTimestamp, _startTimestamp + zDAOInfo.duration);
  }

  function cancelProposal(uint256 _proposalId)
    external
    onlyZDAOChef
    isActiveDAO
    onlyValidProposal(_proposalId)
  {
    require(
      !proposals[_proposalId].canceled && !proposals[_proposalId].collected,
      "Already canceled or collected proposal"
    );
    _cancelProposal(_proposalId);
  }

  function executeProposal(uint256 _proposalId)
    external
    onlyZDAOChef
    isActiveDAO
    onlyValidProposal(_proposalId)
  {
    require(
      !proposals[_proposalId].canceled && proposals[_proposalId].collected,
      "Not a valid proposal"
    );
    _executeProposal(_proposalId);
  }

  function collectProposal(uint256 _proposalId)
    external
    onlyZDAOChef
    isActiveDAO
    onlyValidProposal(_proposalId)
    returns (
      uint256 voters,
      uint256 yes,
      uint256 no
    )
  {
    Proposal storage proposal = proposals[_proposalId];
    require(
      !proposal.canceled &&
        !proposal.collected &&
        block.timestamp > proposal.endTimestamp, // proposal has already ended
      "Not a valid proposal"
    );

    voters = proposal.voters;
    yes = proposal.yes;
    no = proposal.no;

    proposal.collected = true;
  }

  function vote(
    uint256 _proposalId,
    address _voter,
    uint256 _choice
  ) external onlyZDAOChef isActiveDAO onlyValidProposal(_proposalId) {
    require(
      _choice == uint256(IPolyZDAO.VoterChoice.Yes) ||
        _choice == uint256(IPolyZDAO.VoterChoice.No),
      "Invalid choice"
    );
    require(_canVote(_proposalId, _voter), "Not valid for voting");

    _vote(_proposalId, _voter, VoterChoice(_choice));
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
    uint256 _startTimestamp,
    uint256 _endTimestamp
  ) internal virtual {
    require(proposals[_proposalId].proposalId == 0, "Already proposal created");
    proposals[_proposalId] = Proposal({
      proposalId: _proposalId,
      startTimestamp: _startTimestamp,
      endTimestamp: _endTimestamp,
      yes: 0,
      no: 0,
      voters: 0,
      snapshot: block.number,
      collected: false,
      executed: false,
      canceled: false
    });
    proposalIds.push(_proposalId);
  }

  function _cancelProposal(uint256 _proposalId) internal virtual {
    proposals[_proposalId].canceled = true;
  }

  function _executeProposal(uint256 _proposalId) internal virtual {
    proposals[_proposalId].executed = true;
  }

  function _canVote(uint256 _proposalId, address _voter)
    internal
    view
    virtual
    returns (bool)
  {
    Proposal storage proposal = proposals[_proposalId];
    if (proposal.proposalId != _proposalId || !_isProposalOpen(proposal)) {
      return false;
    }
    return staking.pastStakingPower(_voter, proposal.snapshot) > 0;
  }

  function _vote(
    uint256 _proposalId,
    address _voter,
    VoterChoice _choice
  ) internal virtual {
    Proposal storage proposal = proposals[_proposalId];
    ProposalVotes storage votes = proposalVotes[_proposalId];
    VoterChoice last = votes.votes[_voter].choice;

    uint256 vp = _votingPower(_proposalId, _voter);
    if (last == VoterChoice.Yes) {
      proposal.yes -= vp;
    } else if (last == VoterChoice.No) {
      proposal.no -= vp;
    } else {
      // if VoterChoice.None
      votes.voters.push(_voter);
    }

    votes.votes[_voter].voter = _voter;
    votes.votes[_voter].choice = _choice;
    votes.votes[_voter].votes = vp;

    if (_choice == VoterChoice.Yes) {
      proposal.yes += vp;
    } else if (_choice == VoterChoice.No) {
      proposal.no += vp;
    }
    proposal.voters = votes.voters.length;
  }

  function _canCollectProposal(uint256 _proposalId)
    internal
    view
    virtual
    returns (bool)
  {
    Proposal storage proposal = proposals[_proposalId];
    return proposal.proposalId == _proposalId && _isProposalClosed(proposal);
  }

  function _votingPower(uint256 _proposalId, address _voter)
    internal
    view
    virtual
    returns (uint256)
  {
    return staking.pastStakingPower(_voter, proposals[_proposalId].snapshot);
  }

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function zDAOId() external view override returns (uint256) {
    return zDAOInfo.zDAOId;
  }

  function destroyed() external view override returns (bool) {
    return zDAOInfo.destroyed;
  }

  function numberOfProposals() external view override returns (uint256) {
    return proposalIds.length;
  }

  function listProposals(uint256 _startIndex, uint256 _count)
    external
    view
    override
    returns (Proposal[] memory records)
  {
    uint256 numRecords = _count;
    if (numRecords > (proposalIds.length - _startIndex)) {
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
    } else if (proposal.collected) {
      return ProposalState.Collected;
    }
    return ProposalState.Collecting;
  }

  function votesResultOfProposal(uint256 _proposalId)
    external
    view
    override
    returns (
      uint256 voters,
      uint256 yes,
      uint256 no
    )
  {
    Proposal storage proposal = proposals[_proposalId];

    voters = proposal.voters;
    yes = proposal.yes;
    no = proposal.no;
  }

  function canVote(uint256 _proposalId, address _voter)
    external
    view
    override
    returns (bool)
  {
    return _canVote(_proposalId, _voter);
  }

  function canCollectProposal(uint256 _proposalId)
    external
    view
    override
    returns (bool)
  {
    return _canCollectProposal(_proposalId);
  }

  function choiceOfVoter(uint256 _proposalId, address _voter)
    external
    view
    override
    returns (VoterChoice)
  {
    return proposalVotes[_proposalId].votes[_voter].choice;
  }

  function votingPowerOfVoter(uint256 _proposalId, address _voter)
    external
    view
    override
    returns (uint256)
  {
    return _votingPower(_proposalId, _voter);
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
    if (numRecords > (singleProposalVotes.voters.length - _startIndex)) {
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
