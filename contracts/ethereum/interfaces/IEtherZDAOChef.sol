// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {IERC20Upgradeable} from "../../oz-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IEtherZDAO} from "./IEtherZDAO.sol";

interface IEtherZDAOChef {
  struct ZDAOConfig {
    /// @notice Title of the zDAO
    string title;
    /// @notice Gnosis safe address where collected treasuries are stored
    address gnosisSafe;
    /// @notice Voting token (ERC20 or ERC721) on Ethereum, only token holders
    /// can create a proposal
    address token;
    /// @notice The minimum number of tokens required to become proposal creator
    uint256 amount;
    // True if relative majority to calculate voting result
    bool isRelativeMajority;
    /// @notice The number of votes in support of a proposal required in order
    /// for a vote to succeed
    uint256 quorumVotes;
  }

  struct ZDAORecord {
    /// @notice Unique id for looking up zDAO
    uint256 id;
    /// @notice Address to newly created EtherZDAO contract
    IEtherZDAO zDAO;
    /// @notice Array of zNA ids associated with zDAO
    uint256[] associatedzNAs;
  }

  /* -------------------------------------------------------------------------- */
  /*                                   Events                                   */
  /* -------------------------------------------------------------------------- */

  event DAOCreated(
    uint256 indexed _daoId,
    address indexed _creator,
    address indexed _zDAO
  );

  event DAODestroyed(uint256 indexed _daoId);

  event DAOUpdateGnosisSafe(
    uint256 indexed _daoId,
    address indexed _gnosisSafe
  );

  event DAOUpdateVotingtoken(
    uint256 indexed _daoId,
    address indexed _token,
    uint256 indexed _amount
  );

  event LinkAdded(uint256 indexed _daoId, uint256 indexed _zNA);

  event LinkRemoved(uint256 indexed _daoId, uint256 indexed _zNA);

  event ProposalCreated(
    uint256 indexed _zDAOId,
    uint256 indexed _proposalId,
    address indexed _createdBy,
    uint256 _startTimestamp,
    uint256 _endTimestamp
  );

  event ProposalCanceled(
    uint256 indexed _zDAOId,
    uint256 indexed _proposalId,
    address indexed _cancelBy
  );

  event ProposalExecuted(
    uint256 indexed _zDAOId,
    uint256 indexed _proposalId,
    address indexed _executeBy
  );

  event ProposalCollected(
    uint256 indexed _zDAOId,
    uint256 indexed _propoalId,
    uint256 yes,
    uint256 no
  );

  /* -------------------------------------------------------------------------- */
  /*                             External Functions                             */
  /* -------------------------------------------------------------------------- */

  function addNewDAO(uint256 _zNA, ZDAOConfig calldata _zDAOConfig) external;

  function removeDAO(uint256 _daoId) external;

  function setDAOGnosisSafe(uint256 _daoId, address _gnosisSafe) external;

  function setDAOVotingToken(
    uint256 _daoId,
    address _token,
    uint256 _amount
  ) external;

  function addZNAAssociation(uint256 _daoId, uint256 _zNA) external;

  function removeZNAAssociation(uint256 _daoId, uint256 _zNA) external;

  function createProposal(
    uint256 _daoId,
    uint256 _startTimestamp,
    uint256 _endTimestamp,
    address _target,
    uint256 _value,
    bytes calldata _data,
    bytes32 _ipfs
  ) external;

  function cancelProposal(uint256 _daoId, uint256 _proposalId) external;

  function executeProposal(uint256 _daoId, uint256 _proposalId) external;

  /* -------------------------------------------------------------------------- */
  /*                               View Functions                               */
  /* -------------------------------------------------------------------------- */

  function numberOfzDAOs() external view returns (uint256);

  function getzDAOById(uint256 _daoId)
    external
    view
    returns (ZDAORecord memory);

  function listzDAOs(uint256 _startIndex, uint256 _endIndex)
    external
    view
    returns (ZDAORecord[] memory);

  function getzDaoByZNA(uint256 _zNA) external view returns (ZDAORecord memory);

  function doeszDAOExistForzNA(uint256 _zNA) external view returns (bool);
}
