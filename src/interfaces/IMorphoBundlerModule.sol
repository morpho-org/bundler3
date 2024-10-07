// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title IMorphoBundlerModule
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Minimal interface of Morpho Bundler modules.
interface IMorphoBundlerModule {
    /// @notice Receives a call from the Morpho Bundler.
    function onMorphoBundlerCall(bytes calldata data) external payable;
}
