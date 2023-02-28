// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IZDAORegistryV2 {
  struct ZDAORecord {
    uint256 id;
    string ensSpace;
    address gnosisSafe;
    uint256[] associatedzNAs;
    bool destroyed;
    address token;
  }

  function numberOfzDAOs() external view returns (uint256);

  function getzDAOById(uint256 zDAOId) external view returns (ZDAORecord memory);

  function getzDAOAssociations(uint256 zDAOId) external view returns (uint256[] memory);

  function getzDAOByENS(string calldata ensSpace) external view returns (ZDAORecord memory);

  function listzDAOs(uint256 startIndex, uint256 endIndex)
    external
    view
    returns (ZDAORecord[] memory);

  function doeszDAOExistForzNA(uint256 zNA) external view returns (bool);

  function getzDAOByzNA(uint256 zNA) external view returns (ZDAORecord memory);

  event ZNSHubChanged(address zNSHub);
  event DAOCreated(uint256 indexed zDAOId, string ensSpace, address gnosisSafe);
  event DAOCreatedWithToken(
    uint256 indexed zDAOId,
    string ensSpace,
    address gnosisSafe,
    address token
  );
  event DAOModified(uint256 indexed zDAOId, string ensSpace, address gnosisSafe);
  event DAOGnosisSafeModified(uint256 indexed zDAOId, address gnosisSafe);
  event DAODestroyed(uint256 indexed zDAOId);
  event LinkAdded(uint256 indexed zDAOId, uint256 indexed zNA);
  event LinkRemoved(uint256 indexed zDAOId, uint256 indexed zNA);
}
