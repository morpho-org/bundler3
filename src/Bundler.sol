// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IBundler, Call} from "./interfaces/IBundler.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {UtilsLib} from "./libraries/UtilsLib.sol";

/// @custom:contact security@morpho.org
/// @notice Enables calling multiple functions in a single call to multiple contracts ("targets").
/// @notice Transiently stores the initiator of the multicall transaction.
/// @notice Transiently stores the current target that is being called.
contract Bundler is IBundler {
    /* TRANSIENT STORAGE */

    /// @notice The initiator of the multicall transaction.
    address public transient initiator;

    /// @notice The current target.
    /// @notice A target becomes the "currentTarget" upon being called.
    address public transient currentTarget;

    /* EXTERNAL */

    /// @notice Executes a series of calls to targets.
    /// @dev Locks the initiator so that the sender can be identified by targets.
    /// @param bundle The ordered array of calldata to execute.
    function multicall(Call[] calldata bundle) external payable {
        require(initiator == address(0), ErrorsLib.AlreadyInitiated());

        initiator = msg.sender;

        _multicall(bundle);

        initiator = msg.sender;
    }

    /// @notice Executes a series of calls to targets.
    /// @dev Useful during callbacks.
    /// @dev Can only be called by the current target.
    /// @param bundle The ordered array of calldata to execute.
    function multicallFromTarget(Call[] calldata bundle) external {
        require(msg.sender == currentTarget, ErrorsLib.UnauthorizedSender());
        _multicall(bundle);
    }

    /* INTERNAL */

    /// @notice Executes a series of calls to targets.
    function _multicall(Call[] calldata bundle) internal {
        address previousTarget = currentTarget;

        for (uint256 i; i < bundle.length; ++i) {
            address target = bundle[i].to;

            currentTarget = target;

            (bool success, bytes memory returnData) = target.call{value: bundle[i].value}(bundle[i].data);
            if (!bundle[i].skipRevert && !success) UtilsLib.lowLevelRevert(returnData);
        }

        currentTarget = previousTarget;
    }
}
