// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {IERC20Upgradeable} from "../../oz-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IEtherZDAOChef} from "./IEtherZDAOChef.sol";

interface IEtherZDAO {
  struct ZDAOInfo {
    uint256 zDAOId; // zDAO id
    address owner; // zDAO owner
    string name; // zDAO name
    address gnosisSafe;
    address token; // voting token (ERC20 or ERC721)
    uint256 amount; // minimum voting token amount to create a proposal
    uint256 minPeriod; // minimum voting period
    bool isRelativeMajority;
    uint256 threshold; // percent in 10000 as 100%
    uint256 snapshot;
    bool destroyed;
  }

  enum ProposalState {
    Active,
    Executed,
    Deleted
  }

  struct Proposal {
    uint256 proposalId;
    address createdBy;
    uint256 startTimestamp;
    uint256 endTimestamp;
    uint256 yes;
    uint256 no;
    uint256 reserved;
    // ipfs hash: https://stackoverflow.com/questions/66927626/how-to-store-ipfs-hash-on-ethereum-blockchain-using-smart-contracts
    bytes32 ipfs;
    IERC20Upgradeable token;
    uint256 amount;
    uint256 snapshot;
    ProposalState state;
  }

  /* -------------------------------------------------------------------------- */
  /*                                   Events                                   */
  /* -------------------------------------------------------------------------- */

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function __ZDAO_init(
    address _zDAOChef,
    uint256 _zDAOId,
    address _zDAOOwner,
    IEtherZDAOChef.ZDAOConfig calldata _zDAOConfig
  ) external;

  function setDestroyed(bool _destroyed) external;

  function setGnosisSafe(address _gnosisSafe) external;

  function setVotingToken(address _token, uint256 _amount) external;

  function createProposal(
    address _createdBy,
    uint256 _startTimestamp,
    uint256 _endTimestamp,
    IERC20Upgradeable _token,
    uint256 _amount,
    bytes32 _ipfs
  ) external returns (uint256);

  function executeProposal(uint256 _proposalId) external;

  function setVoteResult(
    uint256 _proposalId,
    uint256 _yes,
    uint256 _no
  ) external;

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function zDAOOwner() external view returns (address);

  function destroyed() external view returns (bool);

  function numberOfProposals() external view returns (uint256);

  function listProposals(uint256 _startIndex, uint256 _endIndex)
    external
    view
    returns (Proposal[] memory);
}
