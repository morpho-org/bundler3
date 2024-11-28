// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

/// @notice Struct containing all the data needed to make a call.
struct Call {
    bool skipRevert;
    address to;
    bytes data;
    uint256 value;
}

/// @title IBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Interface of Bundler.
interface IBundler {
    function multicall(Call[] calldata bundle) external payable;
    function multicallFromModule(Call[] calldata bundle) external;
    function currentModule() external view returns (address module);
    function initiator() external view returns (address);
}
