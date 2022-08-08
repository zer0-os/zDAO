// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

interface IZDAOModule {
  function isProposalExecuted(uint256 _platformType, uint256 _proposalHash)
    external
    view
    returns (bool);
}
