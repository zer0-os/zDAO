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
  mapping(uint256 => mapping(address => VoterChoice)) voters;
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

  modifier onlyStaker(address _voter) {
    require(
      staking.userStaked(_voter, address(zDAOInfo.mappedToken)) > 0,
      "Only for staker"
    );
    _;
  }

  modifier onlyValidProposal(uint256 _proposalId) {
    require(
      proposals[_proposalId].proposalId == _proposalId &&
        proposals[_proposalId].state != IPolyZDAO.ProposalState.Deleted,
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
    address _mappedToken, // token address on Polygon
    bool _isRelativeMajority,
    uint256 _threshold
  ) public initializer {
    ZeroUpgradeable.__ZeroUpgradeable_init();

    zDAOChef = _zDAOChef;
    staking = Staking(_staking);
    zDAOInfo = ZDAOInfo({
      zDAOId: _zDAOId,
      mappedToken: _mappedToken,
      isRelativeMajority: _isRelativeMajority,
      threshold: _threshold,
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

    // lock staked amount until proposal ends
    staking.lock(address(zDAOInfo.mappedToken));
  }

  function vote(
    uint256 _proposalId,
    address _voter,
    uint256 _choice
  )
    external
    onlyZDAOChef
    isActiveDAO
    onlyValidProposal(_proposalId)
    onlyStaker(_voter)
  {
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

    // unlock staked tokens if proposal has been closed
    staking.unlock(address(zDAOInfo.mappedToken));

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
      _proposal.state == ProposalState.Active;
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
      state: IPolyZDAO.ProposalState.Active
    });
    proposalIds.push(_proposalId);
  }

  function _canVote(uint256 _proposalId, address)
    internal
    view
    virtual
    returns (bool)
  {
    Proposal storage proposal = proposals[_proposalId];
    return proposal.proposalId == _proposalId && _isProposalOpen(proposal);
  }

  function _vote(
    uint256 _proposalId,
    address _voter,
    VoterChoice _choice
  ) internal virtual {
    Proposal storage proposal = proposals[_proposalId];
    VoterChoice last = voters[_proposalId][_voter];

    uint256 count = zDAOInfo.isRelativeMajority
      ? staking.userStaked(_voter, zDAOInfo.mappedToken)
      : 1;
    if (last == VoterChoice.Yes) {
      proposal.yes -= count;
    } else if (last == VoterChoice.No) {
      proposal.no -= count;
    }

    voters[_proposalId][_voter] = _choice;
    if (_choice == VoterChoice.Yes) {
      proposal.yes += count;
    } else if (_choice == VoterChoice.No) {
      proposal.no += count;
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

  function canVote(uint256 _proposalId, address _voter)
    external
    view
    returns (bool)
  {
    return _canVote(_proposalId, _voter);
  }

  function canCollectResult(uint256 _proposalId) external view returns (bool) {
    return _canCollectResult(_proposalId);
  }

  function getVoterChoice(uint256 _proposalId, address _voter)
    external
    view
    returns (VoterChoice)
  {
    return voters[_proposalId][_voter];
  }
}
