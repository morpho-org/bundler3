// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title IBaseBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Interface of BaseBundler.
interface IBaseBundler {
    /// @notice Executes an ordered batch of delegatecalls to this contract.
    /// @param data The ordered array of calldata to execute.
    function multicall(bytes[] calldata data) external payable;

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

    /// @notice Returns the address of the initiator of the multicall transaction.
    /// @dev Specialized getter to prevent using `_initiator` directly.
    function initiator() external view returns (address);
}
