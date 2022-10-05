// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {ZeroUpgradeable, SafeERC20Upgradeable, IERC20Upgradeable} from "../../abstracts/ZeroUpgradeable.sol";
import {ITunnel} from "../interfaces/ITunnel.sol";
import {IEthereumZDAO} from "./interfaces/IEthereumZDAO.sol";
import {IEthereumZDAOChef} from "./interfaces/IEthereumZDAOChef.sol";

contract EthereumZDAO is ZeroUpgradeable, IEthereumZDAO {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  uint256 public constant divisionConstant = 10000;

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

  modifier onlyValidTokenHolder(address holder) {
    require(
      IERC20Upgradeable(zDAOInfo.token).balanceOf(holder) >= zDAOInfo.amount,
      "Not a valid token holder"
    );
    _;
  }

  modifier isActiveDAO() {
    require(!zDAOInfo.destroyed, "Already destroyed");
    _;
  }

  modifier onlyValidProposal(uint256 proposalId) {
    require(proposalId > 0 && proposalId <= lastProposalId, "Invalid zDAO");
    _;
  }

  /* -------------------------------------------------------------------------- */
  /*                                 Initializer                                */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Initializer function
   * @param zDAOChef_ Address to EthereumZDAOChef contract
   * @param zDAOId Unique id for current zDAO
   * @param gnosisSafe Address to Gnosis Safe
   * @param createdBy Address to zDAO owner
   * @param zDAOConfig Structure of zDAO configuration
   */
  function __ZDAO_init(
    address zDAOChef_,
    uint256 zDAOId,
    address createdBy,
    address gnosisSafe,
    IEthereumZDAOChef.ZDAOConfig calldata zDAOConfig
  ) public initializer {
    ZeroUpgradeable.__ZeroUpgradeable_init();

    zDAOChef = zDAOChef_;

    zDAOInfo = ZDAOInfo({
      zDAOId: zDAOId,
      createdBy: createdBy,
      gnosisSafe: gnosisSafe,
      token: zDAOConfig.token,
      amount: zDAOConfig.amount,
      duration: zDAOConfig.duration,
      votingDelay: zDAOConfig.votingDelay,
      votingThreshold: zDAOConfig.votingThreshold,
      minimumVotingParticipants: zDAOConfig.minimumVotingParticipants,
      minimumTotalVotingTokens: zDAOConfig.minimumTotalVotingTokens,
      snapshot: block.number,
      isRelativeMajority: zDAOConfig.isRelativeMajority,
      destroyed: false
    });
  }

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Destroy the zDAO
   * @dev Callable by EthereumZDAOChef
   * @param destroyed_ Flag marking whether zDAO has been destroyed
   */
  function setDestroyed(bool destroyed_) external override onlyZDAOChef {
    zDAOInfo.destroyed = destroyed_;
  }

  /**
   * @notice Set Gnosis Safe address, Voting Token and minimum holding token amount
   * @dev Callable by EthereumZDAOChef, only available for active zDAO
   * @param gnosisSafe Address to Gnosis Safe wallet
   * @param token Address to Voting Token
   * @param amount Minimum number of tokens required to become proposal creator
   */
  function modifyZDAO(
    address gnosisSafe,
    address token,
    uint256 amount
  ) external override isActiveDAO onlyZDAOChef {
    zDAOInfo.gnosisSafe = gnosisSafe;
    zDAOInfo.token = token;
    zDAOInfo.amount = amount;
  }

  /**
   * @notice Create a proposal with the IPFS which contains proposal meta data
   * @dev Callable by EthereumZDAOChef, only available for active zDAO
   * @param createdBy Address to the proposal owner
   * @param choices Number of choices
   * @param ipfs IPFS hash which contains proposal meta data e.g. body text
   */
  function createProposal(
    address createdBy,
    string[] calldata choices,
    string calldata ipfs
  )
    external
    override
    onlyZDAOChef
    isActiveDAO
    onlyValidTokenHolder(createdBy)
    returns (uint256)
  {
    uint256 proposalId = _createProposal(createdBy, choices, ipfs);

    return proposalId;
  }

  /**
   * @notice Cancel a proposal, proposal owner can only cancel pending proposal
   *      It means that proposal is still synchronizing to Polygon or active.
   * @dev Callable by EthereumZDAOChef, only available for active zDAO and valid
   *      proposal
   * @param cancelBy Address to user who is going to cancel proposal
   * @param proposalId Proposal unique id to cancel
   */
  function cancelProposal(address cancelBy, uint256 proposalId)
    external
    override
    onlyZDAOChef
    isActiveDAO
    onlyValidProposal(proposalId)
  {
    require(
      proposals[proposalId].createdBy == cancelBy,
      "Not a proposal creator"
    );
    ProposalState state2 = this.state(proposalId);
    require(state2 == ProposalState.Pending, "Not a pending proposal");

    proposals[proposalId].canceled = true;
  }

  /**
   * @notice Calculate proposal, anybody can calculate proposal.
   *     Through proposal calculation, zDAO can receive the final voting result
   *     from the Polygon. This function should be executed only when zDAOChef
   *     receives the CalculateProposal event from the Polygon.
   *     Proposal state is pending state until proposal calculation.
   * @dev Callable by EthereumZDAOchef, only available for active zDAO and valid
   *     proposal
   * @param proposalId Proposal unique id to execute
   * @param voters Number of voters who participated in
   * @param votes Array of number of all the casted votes
   */
  function calculateProposal(
    uint256 proposalId,
    uint256 voters,
    uint256[] calldata votes
  ) external override onlyZDAOChef onlyValidProposal(proposalId) {
    Proposal storage proposal = proposals[proposalId];
    require(!proposal.calculated, "Already calculated proposal");

    ProposalState state2 = this.state(proposalId);
    require(state2 == ProposalState.Pending, "Not a pending proposal");

    require(
      votes.length == proposal.votes.length,
      "Not match length of votes"
    );

    proposal.voters = voters;
    for (uint256 i = 0; i < votes.length; i++) {
      proposal.votes[i] = votes[i];
    }

    proposals[proposalId].calculated = true;
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal Functions                             */
  /* -------------------------------------------------------------------------- */

  function _createProposal(
    address createdBy,
    string[] memory choices,
    string memory ipfs
  ) internal virtual returns (uint256 proposalId) {
    lastProposalId++;

    proposals[lastProposalId] = Proposal({
      proposalId: lastProposalId,
      createdBy: createdBy,
      created: block.timestamp,
      voters: 0,
      ipfs: ipfs,
      snapshot: block.number,
      calculated: false,
      canceled: false,
      choices: choices,
      votes: new uint256[](choices.length)
    });
    proposalIds.push(lastProposalId);

    return lastProposalId;
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

  function getZDAOOwner() external view returns (address) {
    return zDAOInfo.createdBy;
  }

  function destroyed() external view returns (bool) {
    return zDAOInfo.destroyed;
  }

  function numberOfProposals() external view override returns (uint256) {
    return lastProposalId;
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
    if (lastProposalId <= startIndex) {
      numRecords = 0;
    } else if (numRecords > (lastProposalId - startIndex)) {
      numRecords = lastProposalId - startIndex;
    }

    records = new Proposal[](numRecords);

    for (uint256 i = 0; i < numRecords; ++i) {
      records[i] = proposals[startIndex + i + 1];
    }

    return records;
  }

  /**
   * @notice Return the proposal state
   *     Canceled if already canceled
   *     Pending if the proposal is synchronizing to Polygon or already started,
   *       but not calculated yet
   *     Closed if proposal is successfully finalized
   */
  function state(uint256 proposalId)
    external
    view
    override
    returns (ProposalState)
  {
    Proposal storage proposal = proposals[proposalId];
    if (proposal.canceled) {
      return ProposalState.Canceled;
    } else if (!proposal.calculated) {
      return ProposalState.Pending;
    }
    return ProposalState.Closed;
  }
}
