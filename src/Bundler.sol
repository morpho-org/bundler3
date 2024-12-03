// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IBundler, Call} from "./interfaces/IBundler.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {ModuleLib} from "./libraries/ModuleLib.sol";

/// @custom:contact security@morpho.org
/// @notice Enables calling multiple functions in a single call to multiple contracts ("modules").
/// @notice Transiently stores the initiator of the multicall transaction.
/// @notice Transiently stores the current module that is being called.
contract Bundler is IBundler {
    /* TRANSIENT STORAGE */

    /// @notice The initiator of the multicall transaction.
    address public transient initiator;

    /// @notice The current module.
    /// @notice A module becomes the current module upon being called.
    address public transient currentModule;

    /* EXTERNAL */

    /// @notice Executes a series of calls to modules.
    /// @dev Locks the initiator so that the sender can be identified by modules.
    /// @param bundle The ordered array of calldata to execute.
    function multicall(Call[] calldata bundle) external payable {
        require(initiator == address(0), ErrorsLib.AlreadyInitiated());

        initiator = msg.sender;

        _multicall(bundle);

        initiator = address(0);
    }

    /// @notice Executes a series of calls to modules.
    /// @dev Useful during callbacks.
    /// @dev Can only be called by the current module.
    /// @param bundle The ordered array of calldata to execute.
    function multicallFromModule(Call[] calldata bundle) external {
        require(msg.sender == currentModule, ErrorsLib.UnauthorizedSender());
        _multicall(bundle);
    }

    /* INTERNAL */

    /// @notice Executes a series of calls to modules.
    function _multicall(Call[] calldata bundle) internal {
        address previousModule = currentModule;

        for (uint256 i; i < bundle.length; ++i) {
            address module = bundle[i].to;

            currentModule = module;

            (bool success, bytes memory returnData) = module.call{value: bundle[i].value}(bundle[i].data);
            if (!bundle[i].skipRevert && !success) ModuleLib.lowLevelRevert(returnData);
        }

        currentModule = previousModule;
    }
}
