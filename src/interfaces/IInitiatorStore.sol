// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title IInitiatorStore
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Part of Morpho Bundler able to return the current initiator value.
interface IInitiatorStore {
    /// @notice Returns the address of the initiator of the multicall transaction.
    /// @dev Specialized getter to prevent using `_initiator` directly.
    function initiator() external view returns (address);
}
