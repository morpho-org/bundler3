// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {Call} from "./Call.sol";

/// @title IHub
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Interface of Hub.
interface IHub {
    /// @notice Executes an ordered batch of delegatecalls to this contract.
    /// @param data The ordered array of calldata to execute.
    function multicall(Call[] calldata data) external payable;

    /// @notice Responds to calls from the current bundler.
    /// @dev Triggers `_multicall` logic during a callback.
    /// @dev Only the current bundler can call this function.
    function multicallFromBundler(Call[] calldata data) external payable;

    /// @notice Returns the current bundler.
    /// @notice A bundler takes the 'current' status when called.
    /// @notice A bundler gives back the 'current' status to the previously current bundler when it returns from a call.
    /// @notice The initial current bundler is address(0).
    function currentBundler() external view returns (address bundler);

    /// @notice Returns the address of the initiator of the multicall transaction.
    /// @dev Specialized getter to prevent using `_initiator` directly.
    function initiator() external view returns (address);
}
