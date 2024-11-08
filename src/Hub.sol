// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {IHub} from "./interfaces/IHub.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {INITIATOR_SLOT} from "./libraries/ConstantsLib.sol";
import {CURRENT_BUNDLER_SLOT} from "./libraries/ConstantsLib.sol";
import {Call} from "./interfaces/Call.sol";
import {BundlerLib} from "./libraries/BundlerLib.sol";

/// @title Hub
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Enables calling multiple functions in a single call to multiple contracts ("bundlers").
/// @notice Stores the initiator of the multicall transaction.
/// @notice Stores the current bundler that is about to be called.
contract Hub is IHub {
    /* STORAGE FUNCTIONS */

    /// @notice Set the initiator value in transient storage.
    function setInitiator(address _initiator) internal {
        assembly ("memory-safe") {
            tstore(INITIATOR_SLOT, _initiator)
        }
    }

    /* PUBLIC */

    /// @notice Returns the address of the initiator of the multicall transaction.
    /// @dev Specialized getter to prevent using `_initiator` directly.
    function initiator() public view returns (address _initiator) {
        assembly ("memory-safe") {
            _initiator := tload(INITIATOR_SLOT)
        }
    }

    /// @notice Returns the current bundler.
    /// @notice A bundler takes the 'current' status when called.
    /// @notice A bundler gives back the 'current' status to the previously current bundler when it returns from a call.
    /// @notice The initial current bundler is address(0).
    function currentBundler() public view returns (address bundler) {
        assembly ("memory-safe") {
            bundler := tload(CURRENT_BUNDLER_SLOT)
        }
    }

    /* EXTERNAL */

    /// @notice Executes a series of calls to bundlers.
    /// @dev Locks the initiator so that the sender can uniquely be identified in callbacks.
    /// @param calls The ordered array of calldata to execute.
    function multicall(Call[] calldata calls) external payable {
        require(initiator() == address(0), ErrorsLib.AlreadyInitiated());

        setInitiator(msg.sender);

        _multicall(calls);

        setInitiator(address(0));
    }

    /// @notice Responds to calls from the current bundler.
    /// @param data The bundle to execute, a Call array in a bytes array.
    /// @dev The call array is expected as bytes to avoid unnecessary abi decoding and encoding higher in the call
    /// stack.
    /// @dev Triggers `_multicall` logic during a callback.
    /// @dev Only the current bundler can call this function.
    /// @dev Directly reads the calls from calldata to save gas.
    function multicallFromBundler(bytes calldata data) external payable {
        require(msg.sender == currentBundler(), ErrorsLib.UnauthorizedSender(msg.sender));
        Call[] calldata calls = toCallArray(data);
        _multicall(calls);
    }

    /* INTERNAL */

    /// @notice Executes a series of calls to bundlers
    /// @dev Calls are in calldata
    function _multicall(Call[] calldata calls) internal {
        for (uint256 i; i < calls.length; ++i) {
            address previousBundler = currentBundler();
            address bundler = calls[i].to;
            setCurrentBundler(bundler);
            (bool success, bytes memory returnData) = bundler.call{value: calls[i].value}(calls[i].data);

            if (!success) {
                BundlerLib.lowLevelRevert(returnData);
            }

            setCurrentBundler(previousBundler);
        }
    }

    /// @notice Set the bundler that is about to be called.
    function setCurrentBundler(address bundler) internal {
        assembly ("memory-safe") {
            tstore(CURRENT_BUNDLER_SLOT, bundler)
        }
    }

    /// @notice Cast bytes calldata to a call array.
    /// @param data The calldata to cast.
    function toCallArray(bytes calldata data) internal pure returns (Call[] calldata bundle) {
        assembly {
            bundle.offset := add(data.offset, 64)
            bundle.length := calldataload(add(data.offset, 32))
        }
    }
}
