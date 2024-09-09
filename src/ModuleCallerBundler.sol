// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.24;

import {IMorphoBundlerModule} from "./interfaces/IMorphoBundlerModule.sol";
import {BaseBundler} from "./BaseBundler.sol";

/// @title ModuleCallerBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Bundler contract managing calls to external bundler module contracts
abstract contract ModuleCallerBundler is BaseBundler {
    /// @notice Calls `module`, passing along `data` and the current `initiator`.
    function callModule(address module, bytes calldata data) external payable protected {
        IMorphoBundlerModule(module).morphoBundlerModuleCall(initiator(), data);
    }
}
