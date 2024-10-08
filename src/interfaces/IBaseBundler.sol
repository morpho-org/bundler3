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

    /// @notice Returns the address of the initiator of the multicall transaction.
    /// @dev Specialized getter to prevent using `_initiator` directly.
    function initiator() external view returns (address);
}
