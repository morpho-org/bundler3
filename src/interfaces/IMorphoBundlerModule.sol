// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title IMorphoBundlerModule
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Interface of Morpho Bundler module.
interface IMorphoBundlerModule {
    /// @notice Receives a call from the Morpho Bundler.
    function morphoBundlerModuleCall(address initiator, bytes calldata data) external payable;
}
