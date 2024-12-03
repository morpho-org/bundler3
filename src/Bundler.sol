// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IBundler, Call} from "./interfaces/IBundler.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {UtilsLib} from "./libraries/UtilsLib.sol";

/// @custom:contact security@morpho.org
/// @notice Enables batching multiple calls in a single one.
/// @notice Transiently stores the initiator of the multicall.
/// @notice Can be reentered by the last unreturned Call.
/// @dev Anybody can do arbitrary calls with this contract, so it should not be approved/authorized anywhere.
contract Bundler is IBundler {
    /* TRANSIENT STORAGE */

    /// @notice The initiator of the multicall transaction.
    address public transient initiator;

    /// @notice Last non-returned Call (Call=call from the bundler).
    address public transient lastUnreturnedCall;

    /* EXTERNAL */

    /// @notice Executes a series of calls.
    /// @dev Locks the initiator so that the sender can be identified by other contracts.
    /// @param bundle The ordered array of calldata to execute.
    function multicall(Call[] calldata bundle) external payable {
        require(initiator == address(0), ErrorsLib.AlreadyInitiated());

        initiator = msg.sender;

        _multicall(bundle);

        initiator = address(0);
    }

    /// @notice Executes a series of calls.
    /// @dev Useful during callbacks.
    /// @dev Can only be called by the last unreturned Call.
    /// @param bundle The ordered array of calldata to execute.
    function reenter(Call[] calldata bundle) external {
        require(msg.sender == lastUnreturnedCall, ErrorsLib.UnauthorizedSender());
        _multicall(bundle);
    }

    /* INTERNAL */

    /// @notice Executes a series of calls.
    function _multicall(Call[] calldata bundle) internal {
        address previousLastUnreturnedCall = lastUnreturnedCall;

        for (uint256 i; i < bundle.length; ++i) {
            address to = bundle[i].to;

            lastUnreturnedCall = to;

            (bool success, bytes memory returnData) = to.call{value: bundle[i].value}(bundle[i].data);
            if (!bundle[i].skipRevert && !success) UtilsLib.lowLevelRevert(returnData);
        }

        lastUnreturnedCall = previousLastUnreturnedCall;
    }
}
