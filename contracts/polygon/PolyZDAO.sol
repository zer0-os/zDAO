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
  mapping(uint256 => ProposalVotes) proposalVotes;

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
      proposals[_proposalId].proposalId == _proposalId &&
        !proposals[_proposalId].executed &&
        !proposals[_proposalId].canceled,
      "Invalid zDAO"
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
    bool _isRelativeMajority,
    uint256 _quorumVotes
  ) public initializer {
    ZeroUpgradeable.__ZeroUpgradeable_init();

    zDAOChef = _zDAOChef;
    staking = Staking(_staking);
    zDAOInfo = ZDAOInfo({
      zDAOId: _zDAOId,
      isRelativeMajority: _isRelativeMajority,
      quorumVotes: _quorumVotes,
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
    uint256 _startTimestamp,
    uint256 _endTimestamp
  ) external onlyZDAOChef isActiveDAO {
    require(
      _proposalId > 0 && proposals[_proposalId].proposalId == 0,
      "Proposal was already created"
    );

    _createProposal(_proposalId, _startTimestamp, _endTimestamp);
  }

  function cancelProposal(uint256 _proposalId)
    external
    onlyZDAOChef
    isActiveDAO
    onlyValidProposal(_proposalId)
  {
    _cancelProposal(_proposalId);
  }

  function executeProposal(uint256 _proposalId)
    external
    onlyZDAOChef
    isActiveDAO
    onlyValidProposal(_proposalId)
  {
    _executeProposal(_proposalId);
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

  function collectResult(uint256 _proposalId)
    external
    onlyZDAOChef
    isActiveDAO
    onlyValidProposal(_proposalId)
    returns (
      bool isRelativeMajority,
      uint256 yes,
      uint256 no
    )
  {
    require(_canCollectResult(_proposalId), "Not valid for collecting result");

    Proposal storage proposal = proposals[_proposalId];

    isRelativeMajority = zDAOInfo.isRelativeMajority;
    yes = proposal.yes;
    no = proposal.no;
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
      !_proposal.canceled &&
      !_proposal.executed;
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
      reserved: 0,
      snapshot: block.number,
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

    uint256 vp = _votingPower(_voter);
    if (last == VoterChoice.Yes) {
      proposal.yes -= vp;
    } else if (last == VoterChoice.No) {
      proposal.no -= vp;
    } else {
      // if VoterChoice.None
      votes.voters.push(_voter);
    }

    votes.votes[_voter].choice = _choice;
    votes.votes[_voter].votes = vp;

    if (_choice == VoterChoice.Yes) {
      proposal.yes += vp;
    } else if (_choice == VoterChoice.No) {
      proposal.no += vp;
    }
  }

  function _canCollectResult(uint256 _proposalId)
    internal
    view
    virtual
    returns (bool)
  {
    Proposal storage proposal = proposals[_proposalId];
    return proposal.proposalId == _proposalId && _isProposalClosed(proposal);
  }

  function _votingPower(address _voter)
    internal
    view
    virtual
    returns (uint256)
  {
    return !zDAOInfo.isRelativeMajority ? 1 : staking.stakingPower(_voter);
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

  function listProposals(uint256 _startIndex, uint256 _endIndex)
    external
    view
    override
    returns (Proposal[] memory)
  {
    require(_startIndex > 0, "should start index > 0");
    require(_startIndex <= _endIndex, "should start index <= end");
    require(_startIndex <= proposalIds.length, "should start index <= length");
    require(_endIndex <= proposalIds.length, "should end index <= length");

    uint256 numRecords = _endIndex - _startIndex + 1;
    Proposal[] memory records = new Proposal[](numRecords);

    for (uint256 i = 0; i < numRecords; ++i) {
      records[i] = proposals[proposalIds[_startIndex + i - 1]];
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
    } else if (
      proposal.yes <= proposal.no || proposal.yes < zDAOInfo.quorumVotes
    ) {
      return ProposalState.Failed;
    } else if (proposal.executed) {
      return ProposalState.Executed;
    }
    return ProposalState.Succeeded;
  }

  function votesResultOfProposal(uint256 _proposalId)
    external
    view
    override
    onlyValidProposal(_proposalId)
    returns (uint256 yes, uint256 no)
  {
    Proposal storage proposal = proposals[_proposalId];

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

  function canCollectResult(uint256 _proposalId)
    external
    view
    override
    returns (bool)
  {
    return _canCollectResult(_proposalId);
  }

  function choiceOfVoter(uint256 _proposalId, address _voter)
    external
    view
    override
    returns (VoterChoice)
  {
    return proposalVotes[_proposalId].votes[_voter].choice;
  }

  function votingPowerOfVoter(address _voter)
    external
    view
    override
    returns (uint256)
  {
    return _votingPower(_voter);
  }

  function listVoters(
    uint256 _proposalId,
    uint256 _startIndex,
    uint256 _endIndex
  )
    external
    view
    override
    onlyValidProposal(_proposalId)
    returns (
      address[] memory voters,
      uint256[] memory choices,
      uint256[] memory votes
    )
  {
    ProposalVotes storage singleProposalVotes = proposalVotes[_proposalId];

    require(_startIndex > 0, "should start index > 0");
    require(_startIndex <= _endIndex, "should start index <= end");
    require(
      _startIndex <= singleProposalVotes.voters.length,
      "should start index <= length"
    );
    require(
      _endIndex <= singleProposalVotes.voters.length,
      "should end index <= length"
    );

    uint256 numRecords = _endIndex - _startIndex + 1;

    voters = new address[](numRecords);
    choices = new uint256[](numRecords);
    votes = new uint256[](numRecords);

    address voter;
    for (uint256 i = 0; i < numRecords; ++i) {
      voter = singleProposalVotes.voters[_startIndex + i - 1];
      voters[i] = singleProposalVotes.votes[voter].voter;
      choices[i] = uint256(singleProposalVotes.votes[voter].choice);
      votes[i] = singleProposalVotes.votes[voter].votes;
    }
  }
}
