// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IBundler, Call} from "./interfaces/IBundler.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {CURRENT_BUNDLE_HASH_INDEX_SLOT, BUNDLE_HASH_0_SLOT} from "./libraries/ConstantsLib.sol";
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

    /// @notice Last unreturned callee.
    address public transient lastUnreturnedCallee;

    /* EXTERNAL */

    /// @notice Executes a sequence of calls.
    /// @dev Locks the initiator so that the sender can uniquely be identified in callbacks.
    /// @param initialBundle The ordered array of calldata to execute.
    /// @param callbackBundlesHashes The ordered hashes of bundles that will be executed through `multicallFromBundler`.
    /// @dev The number of given hashes must exactly match the number of subsequent calls.
    function multicall(Call[] calldata initialBundle, bytes32[] calldata callbackBundlesHashes) external payable {
        require(initiator == address(0), ErrorsLib.AlreadyInitiated());

        initiator = msg.sender;

        for (uint256 i = 0; i < callbackBundlesHashes.length; i++) {
            bytes32 bundleHash = callbackBundlesHashes[i];
            // Null hash forbidden: it marks the end of the bundle hashes.
            require(bundleHash != bytes32(0), ErrorsLib.NullHash());
            setBundleHashAtIndex(bundleHash, i);
        }

        _multicall(initialBundle);

        require(useBundleHash() == bytes32(0), ErrorsLib.MissingBundle());

        initiator = address(0);
    }

    /// @notice Executes a sequence of calls.
    /// @dev The `bundle` is checked against its hash, stored at the beginning of the initial bundle execution.
    /// @dev Useful during callbacks.
    /// @dev Can only be called by the last unreturned callee.
    /// @param bundle The ordered array of calldata to execute.
    function reenter(Call[] calldata bundle) external {
        require(msg.sender == lastUnreturnedCallee, ErrorsLib.UnauthorizedSender());
        require(useBundleHash() == keccak256(msg.data[4:]), ErrorsLib.InvalidBundle());
        _multicall(bundle);
    }

    /* INTERNAL */

    /// @notice Executes a sequence of calls.
    function _multicall(Call[] calldata bundle) internal {
        address previousLastUnreturnedCallee = lastUnreturnedCallee;

        for (uint256 i; i < bundle.length; ++i) {
            address to = bundle[i].to;

            lastUnreturnedCallee = to;

            (bool success, bytes memory returnData) = to.call{value: bundle[i].value}(bundle[i].data);
            if (!bundle[i].skipRevert && !success) UtilsLib.lowLevelRevert(returnData);
        }

        lastUnreturnedCallee = previousLastUnreturnedCallee;
    }

    /// @notice Transiently store `_hash` at index `index`.
    /// @param bundleHash The hash to store.
    /// @param index The index at which to store the hash.
    function setBundleHashAtIndex(bytes32 bundleHash, uint256 index) internal {
        assembly ("memory-safe") {
            tstore(add(BUNDLE_HASH_0_SLOT, index), bundleHash)
        }
    }

    /// @notice Return the current hash in the sequence and move to the next index.
    /// @dev The current index starts at 0 and is stored in transient storage.
    function useBundleHash() internal returns (bytes32 bundleHash) {
        assembly ("memory-safe") {
            let index := tload(CURRENT_BUNDLE_HASH_INDEX_SLOT)
            tstore(CURRENT_BUNDLE_HASH_INDEX_SLOT, add(index, 1))
            bundleHash := tload(add(BUNDLE_HASH_0_SLOT, index))
        }
    }
}
