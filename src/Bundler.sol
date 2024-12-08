// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IBundler, Call} from "./interfaces/IBundler.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {UtilsLib} from "./libraries/UtilsLib.sol";

/// @custom:contact security@morpho.org
/// @notice Enables batching multiple calls in a single one.
/// @notice Transiently stores the initiator of the multicall.
/// @notice Can be reentered by the last unreturned callee.
/// @dev Anybody can do arbitrary calls with this contract, so it should not be approved/authorized anywhere.
contract Bundler is IBundler {
    /* TRANSIENT STORAGE */

    /// @notice The initiator of the multicall transaction.
    address public transient initiator;

    /// @notice Hash of the concatenation of the next reenter sender and calldata.
    bytes32 public transient reenterHash;

    /* EXTERNAL */

    /// @notice Executes a sequence of calls.
    /// @dev Locks the initiator so that the sender can be identified by other contracts.
    /// @param bundle The ordered array of calldata to execute.
    function multicall(Call[] calldata bundle) external payable {
        require(initiator == address(0), ErrorsLib.AlreadyInitiated());

        initiator = msg.sender;

        _multicall(bundle);

        initiator = address(0);
    }

    /// @notice Executes a sequence of calls.
    /// @dev Useful during callbacks.
    /// @dev Can only be called by the last unreturned callee.
    /// @param bundle The ordered array of calldata to execute.
    function reenter(Call[] calldata bundle) external {
        require(
            reenterHash == keccak256(bytes.concat(bytes20(msg.sender), msg.data[4:])), ErrorsLib.IncorrectReenterHash()
        );
         reenterHash = bytes32(0);

        // Reenter hash is reset to 0 at the end of _multicall, so multiple reenter are impossible.
        _multicall(bundle);
    }

    /* INTERNAL */

    /// @notice Executes a sequence of calls.
    function _multicall(Call[] calldata bundle) internal {
        for (uint256 i; i < bundle.length; ++i) {
            reenterHash = bundle[i].reenterHash;

            (bool success, bytes memory returnData) = bundle[i].to.call{value: bundle[i].value}(bundle[i].data);
            if (!bundle[i].skipRevert && !success) UtilsLib.lowLevelRevert(returnData);

            require(reenterHash == bytes32(0), ErrorsLib.MissingExpectedReenter());
        }

    }
}
