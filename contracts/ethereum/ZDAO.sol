// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../libraries/ZDAOLib.sol";
import "./interfaces/IRootTunnel.sol";

contract ZDAO is Ownable {
  using ZDAOLib for ZDAOLib.ZDAOInfo;
  using SafeERC20 for IERC20;

  struct Proposal {
    address author;
    uint256 startTimestamp;
    uint256 endTimestamp;
    IERC20 token;
    uint256 amount;
    uint256 threshold;
    bool isRelativeMajority;
    // ipfs hash: https://stackoverflow.com/questions/66927626/how-to-store-ipfs-hash-on-ethereum-blockchain-using-smart-contracts
    bytes32 ipfs;
    bool executed;
  }

  ZDAOLib.ZDAOInfo public zDAOInfo;

  uint256 private lastProposalId;
  mapping(uint256 => Proposal) public proposals;
  IRootTunnel public rootTunnel;

  /* -------------------------------------------------------------------------- */
  /*                                   Events                                   */
  /* -------------------------------------------------------------------------- */

  event ProposalCreated(
    uint256 indexed _zDAOId,
    address indexed _proposalAuthor,
    uint256 indexed _proposalId,
    uint256 _startTimestamp,
    uint256 _endTimestamp
  );

  event ProposalExecuted(uint256 indexed _zDAOId, uint256 indexed _proposalId);

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

  constructor(IRootTunnel _rootTunnel, ZDAOLib.ZDAOInfo memory _zDAOInfo) {
    rootTunnel = _rootTunnel;
    zDAOInfo = _zDAOInfo;
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function setDestroyed(bool _destroyed) external onlyOwner {
    zDAOInfo.destroyed = _destroyed;
  }

  function setGnosisSafe(address _gnosisSafe) external onlyZDAOOwner {
    zDAOInfo.gnosisSafe = _gnosisSafe;
  }

  function setVotingToken(IERC20 _token, uint256 _amount)
    external
    onlyZDAOOwner
  {
    zDAOInfo.token = _token;
    zDAOInfo.amount = _amount;
  }

  function createProposal(Proposal calldata _proposal)
    external
    onlyValidTokenHolder
  {
    lastProposalId++;

    proposals[lastProposalId] = _proposal;
    proposals[lastProposalId].author = msg.sender;

    emit ProposalCreated(
      zDAOInfo.id,
      msg.sender,
      lastProposalId,
      _proposal.startTimestamp,
      _proposal.endTimestamp
    );
  }

  function executeProposal(uint256 _proposalId) external {
    // TODO
    emit ProposalExecuted(zDAOInfo.id, _proposalId);
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal Functions                             */
  /* -------------------------------------------------------------------------- */

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function zDAOOwner() external view returns (address) {
    return zDAOInfo.owner;
  }

  function destroyed() external view returns (bool) {
    return zDAOInfo.destroyed;
  }

  function numberOfProposals() external view returns (uint256) {
    return lastProposalId;
  }

  function listProposals(uint256 _startIndex, uint256 _endIndex)
    external
    view
    returns (Proposal[] memory)
  {
    require(_startIndex <= _endIndex, "start index > end");
    require(_startIndex <= lastProposalId, "start index > length");
    require(_endIndex <= lastProposalId, "end index > length");

    uint256 numRecords = _endIndex - _startIndex + 1;
    Proposal[] memory records = new Proposal[](numRecords);

    for (uint256 i = 0; i < numRecords; ++i) {
      records[i] = proposals[_startIndex + i + 1];
    }

    return records;
  }
}
