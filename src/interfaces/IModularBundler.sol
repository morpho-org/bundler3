// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title IModularBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Interface of Morpho Module Caller bundler.
interface IModularBundler {
    /// @notice Receives a call from the Morpho Bundler.

    /// @notice Calls `module`, passing along `data` and `value` native tokens to `module`.
    function callModule(address module, bytes calldata data, uint256 value) external payable;

    /// @notice Responds to calls from the current module.
    /// @dev Triggers `_multicall` logic during a callback.
    function multicallFromModule(bytes calldata data) external payable;
}
