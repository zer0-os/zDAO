// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "../abstracts/ZeroUpgradeable.sol";
import "./interfaces/IChildTunnel.sol";
import "./interfaces/IPolyZDAO.sol";

contract PolyZDAO is ZeroUpgradeable, IPolyZDAO {
  IChildTunnel public childTunnel;

  ZDAOInfo public zDAOInfo;

  // <proposal id, Proposal>
  mapping(uint256 => Proposal) public proposals;
  // <proposal id, voter address, VoterChoice>
  mapping(uint256 => mapping(address => VoterChoice)) voters;
  uint256[] public proposalIds;

  /* -------------------------------------------------------------------------- */
  /*                                  Modifiers                                 */
  /* -------------------------------------------------------------------------- */

  modifier onlyChildTunnel() {
    require(msg.sender == address(childTunnel), "Not a ZDAOChef");
    _;
  }

  modifier isActiveDAO() {
    require(!zDAOInfo.destroyed, "Already destroyed");
    _;
  }

  /* -------------------------------------------------------------------------- */
  /*                                 Initializer                                */
  /* -------------------------------------------------------------------------- */

  function __ZDAO_init(
    IChildTunnel _childTunnel,
    uint256 _zDAOId,
    string memory _name,
    address _zDAOOwner,
    bool _isRelativeMajority,
    uint256 _threshold
  ) public initializer {
    ZeroUpgradeable.initialize();

    childTunnel = _childTunnel;
    zDAOInfo = ZDAOInfo({
      zDAOId: _zDAOId,
      owner: _zDAOOwner,
      name: _name,
      isRelativeMajority: _isRelativeMajority,
      threshold: _threshold,
      snapshot: block.number,
      destroyed: false
    });
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function setDestroyed(bool _destroyed) external override onlyChildTunnel {
    zDAOInfo.destroyed = _destroyed;
  }

  function createProposal(
    uint256 _proposalId,
    address _createdBy,
    uint256 _startTimestamp,
    uint256 _endTimestamp,
    IERC20Upgradeable _token, // token on Etherem
    uint256 _amount,
    bytes32 _ipfs
  ) external isActiveDAO onlyChildTunnel {
    require(
      _proposalId > 0 && proposals[_proposalId].proposalId == 0,
      "Proposal was already created"
    );

    _createProposal(
      _proposalId,
      _createdBy,
      _startTimestamp,
      _endTimestamp,
      _token,
      _amount,
      _ipfs
    );

    emit ProposalCreated(
      zDAOInfo.zDAOId,
      _createdBy,
      _proposalId,
      _startTimestamp,
      _endTimestamp
    );
  }

  function vote(uint256 _proposalId, VoterChoice _choice) external isActiveDAO {
    require(_choice != VoterChoice.None, "Invalid choice");
    require(_canVote(_proposalId, msg.sender), "Not valid for voting");

    _vote(_proposalId, msg.sender, _choice);

    emit CastVote(zDAOInfo.zDAOId, _proposalId, uint256(_choice));
  }

  function collectResult(uint256 _proposalId) external isActiveDAO {
    require(_canCollectResult(_proposalId), "Not valid for collecting result");

    Proposal storage proposal = proposals[_proposalId];
    // send collected result to L1
    childTunnel.sendMessageToRoot(
      abi.encode(
        uint256(ITunnel.MessageType.VoteResult),
        zDAOInfo.zDAOId,
        _proposalId,
        proposal.yes,
        proposal.no
      )
    );
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
    address _createdBy,
    uint256 _startTimestamp,
    uint256 _endTimestamp,
    IERC20Upgradeable _token,
    uint256 _amount,
    bytes32 _ipfs
  ) internal virtual {
    require(proposals[_proposalId].proposalId == 0, "Already proposal created");
    proposals[_proposalId] = Proposal({
      proposalId: _proposalId,
      createdBy: _createdBy,
      startTimestamp: _startTimestamp,
      endTimestamp: _endTimestamp,
      yes: 0,
      no: 0,
      reserved: 0,
      ipfs: _ipfs,
      token: _token,
      amount: _amount,
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

    if (last == VoterChoice.Yes) {
      proposal.yes--;
    } else if (last == VoterChoice.No) {
      proposal.no--;
    }

    voters[_proposalId][_voter] = _choice;
    if (_choice == VoterChoice.Yes) {
      proposal.yes++;
    } else if (_choice == VoterChoice.No) {
      proposal.no++;
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

  function zDAOOwner() external view override returns (address) {
    return zDAOInfo.owner;
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
