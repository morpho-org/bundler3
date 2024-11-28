// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {IBundler, Call} from "./interfaces/IBundler.sol";
import {Mode, ModeLib} from "./libraries/ModeLib.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {INITIATOR_SLOT, CURRENT_MODULE_SLOT} from "./libraries/ConstantsLib.sol";
import {ModuleLib} from "./libraries/ModuleLib.sol";

/// @title Bundler
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Enables calling multiple functions in a single call to multiple contracts ("modules").
/// @notice Stores the initiator of the multicall transaction.
/// @notice Stores the current module that is about to be called.
contract Bundler is IBundler {
    using ModeLib for Mode;

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
    /// @param bundle The ordered array of calldata to execute.
    function multicall(Call[] calldata bundle) external payable {
        require(initiator() == address(0), ErrorsLib.AlreadyInitiated());

        setInitiator(msg.sender);

        _multicall(bundle);

        setInitiator(address(0));
    }

    /// @notice Responds to bundle from the current module.
    /// @dev Triggers `_multicall` logic during a callback.
    /// @dev Only the current module can call this function.
    function multicallFromModule(Call[] calldata bundle) external {
        require(msg.sender == currentModule(), ErrorsLib.UnauthorizedSender(msg.sender));
        _multicall(bundle);
    }

    /* INTERNAL */

    /// @notice Executes a series of calls to modules.
    function _multicall(Call[] calldata bundle) internal {
        address previousModule = currentModule();
        for (uint256 i; i < bundle.length; ++i) {
            address module = bundle[i].mode.to();
            setCurrentModule(module);
            (bool success, bytes memory returnData) = module.call{value: bundle[i].value}(bundle[i].data);

            if (!success && !bundle[i].mode.skipRevert()) ModuleLib.lowLevelRevert(returnData);
        }
        setCurrentModule(previousModule);
    }

    /// @notice Set the module that is about to be called.
    function setCurrentModule(address module) internal {
        assembly ("memory-safe") {
            tstore(CURRENT_MODULE_SLOT, module)
        }
    }
}
