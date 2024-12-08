// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

/// @notice Struct containing all the data needed to make a call.
/// @notice If the call will trigger a reenter, the reenterHash should be set to the hash of the reenter calldata.
struct Call {
    address to;
    bytes data;
    uint256 value;
    bool skipRevert;
    bytes32 reenterHash;
}

/// @custom:contact security@morpho.org
interface IBundler {
    function multicall(Call[] calldata) external payable;
    function reenter(Call[] calldata) external;
    function reenterHash() external view returns (bytes32);
    function initiator() external view returns (address);
}
