// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {IBundler} from "./interfaces/IBundler.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {INITIATOR_SLOT} from "./libraries/ConstantsLib.sol";
import {CURRENT_MODULE_SLOT, CURRENT_BUNDLE_HASH_INDEX_SLOT, BUNDLE_HASH_0_SLOT} from "./libraries/ConstantsLib.sol";
import {Call} from "./interfaces/Call.sol";
import {ModuleLib} from "./libraries/ModuleLib.sol";

/// @title Bundler
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Enables calling multiple functions in a single call to multiple contracts ("modules").
/// @notice Stores the initiator of the multicall transaction.
/// @notice Stores the current module that is about to be called.
contract Bundler is IBundler {
    /* STORAGE FUNCTIONS */

    /// @notice Set the initiator value in transient storage.
    function setInitiator(address _initiator) internal {
        assembly ("memory-safe") {
            tstore(INITIATOR_SLOT, _initiator)
        }
    }

    /* PUBLIC */

    /// @notice Returns the address of the initiator of the multicall transaction.
    function initiator() public view returns (address _initiator) {
        assembly ("memory-safe") {
            _initiator := tload(INITIATOR_SLOT)
        }
    }

    /// @notice Returns the current module.
    /// @notice A module takes the 'current' status when called.
    /// @notice A module gives back the 'current' status to the previously current module when it returns from a call.
    /// @notice The initial current module is address(0).
    function currentModule() public view returns (address module) {
        assembly ("memory-safe") {
            module := tload(CURRENT_MODULE_SLOT)
        }
    }

    /* EXTERNAL */

    /// @notice Executes a series of calls to modules.
    /// @dev Locks the initiator so that the sender can uniquely be identified in callbacks.
    /// @param initialBundle The ordered array of calldata to execute.
    /// @param callbackBundlesHashes The ordered hashes of bundles that will be executed through `multicallFromBundler`.
    /// @dev The number of given hashes must exactly match the number of subsequent calls.
    function multicall(Call[] calldata initialBundle, bytes32[] calldata callbackBundlesHashes) external payable {
        require(initiator() == address(0), ErrorsLib.AlreadyInitiated());

        setInitiator(msg.sender);

        for (uint256 i = 0; i < callbackBundlesHashes.length; i++) {
            setBundleHashAtIndex(callbackBundlesHashes[i], i);
        }

        _multicall(initialBundle);

        require(useBundleHash() == hex"", ErrorsLib.MissingBundle());

        setInitiator(address(0));
    }

    /// @notice Responds to bundle from the current module.
    /// @param bundle The actions to execute.
    /// @notice The `bundle` is checked against its hash, stored at the beginning of the initial bundle execution.
    /// @dev Triggers `_multicall` logic during a callback.
    /// @dev Only the current module can call this function.
    function multicallFromModule(Call[] calldata bundle) external payable {
        require(msg.sender == currentModule(), ErrorsLib.UnauthorizedSender(msg.sender));
        require(useBundleHash() == keccak256(callDataArgs()), ErrorsLib.InvalidBundle());

        _multicall(bundle);
    }

    /* INTERNAL */

    /// @notice Executes a series of calls to modules.
    function _multicall(Call[] calldata bundle) internal {
        for (uint256 i; i < bundle.length; ++i) {
            address previousModule = currentModule();
            address module = bundle[i].to;
            setCurrentModule(module);
            (bool success, bytes memory returnData) = module.call{value: bundle[i].value}(bundle[i].data);

            if (!success) {
                ModuleLib.lowLevelRevert(returnData);
            }

            setCurrentModule(previousModule);
        }
    }

    /// @notice Set the module that is about to be called.
    function setCurrentModule(address module) internal {
        assembly ("memory-safe") {
            tstore(CURRENT_MODULE_SLOT, module)
        }
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
        uint256 index;
        assembly ("memory-safe") {
            index := tload(CURRENT_BUNDLE_HASH_INDEX_SLOT)
            tstore(CURRENT_BUNDLE_HASH_INDEX_SLOT, add(index, 1))
            bundleHash := tload(add(BUNDLE_HASH_0_SLOT, index))
        }
    }

    /// @notice Returns bytes [4:] of the calldata.
    function callDataArgs() internal pure returns (bytes memory) {
        bytes memory data = new bytes(msg.data.length - 4);
        assembly ("memory-safe") {
            calldatacopy(add(data, 32), 4, mload(data))
        }
        return data;
    }
}
