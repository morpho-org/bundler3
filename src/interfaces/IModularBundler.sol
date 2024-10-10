// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title IModularBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Interface of Morpho Module Caller bundler.
interface IModularBundler {
    /// @notice Calls `module`, passing along `data` and `value` native tokens to `module`.
    function callModule(address module, bytes calldata data, uint256 value) external payable;

    /// @notice Responds to calls from the current module.
    /// @dev Triggers `_multicall` logic during a callback.
    /// @dev Only the current module can call this function.
    function multicallFromModule(bytes calldata data) external payable;

    /// @notice Returns the current module.
    /// @notice A module takes the 'current' status when called.
    /// @notice A module gives back the 'current' status to the previously current module when it returns from a call.
    /// @notice The initial current module is address(0).
    function currentModule() external view returns (address module);
}
