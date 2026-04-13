// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

/// @notice Struct containing all the data needed to make a call.
/// @notice The call target is `to`, the calldata is `data` with value `value`.
/// @notice If skipRevert is true, the fact that the call reverts will not cause the whole bundle to revert. Use with
/// caution, since all reverts are ignored.
/// @notice If the call will trigger a reenter, the callbackHash should be set to the hash of the reenter bundle data.
/// @notice If callbackHash is set and the call reverts, the whole bundle will revert even if skipRevert is true.
struct Call {
    address to;
    bytes data;
    uint256 value;
    bool skipRevert;
    bytes32 callbackHash;
}

/// @custom:security-contact security@morpho.org
interface IBundler3 {
    function multicall(Call[] calldata) external payable;
    function reenter(Call[] calldata) external;
    function reenterHash() external view returns (bytes32);
    function initiator() external view returns (address);
}
