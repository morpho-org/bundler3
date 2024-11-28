// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {IBundler, Call} from "./interfaces/IBundler.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {INITIATOR_SLOT, CURRENT_MODULE_SLOT} from "./libraries/ConstantsLib.sol";
import {ModuleLib} from "./libraries/ModuleLib.sol";

/// @custom:contact security@morpho.org
/// @notice Enables calling multiple functions in a single call to multiple contracts ("modules").
/// @notice Transiently stores the initiator of the multicall transaction.
/// @notice Transiently stores the current module that is being called.
contract Bundler is IBundler {
    /* STORAGE FUNCTIONS */

    /// @notice Set the initiator value in transient storage.
    function setInitiator(address _initiator) internal {
        assembly ("memory-safe") {
            tstore(INITIATOR_SLOT, _initiator)
        }
    }

    /// @notice Set the module that is about to be called.
    function setCurrentModule(address module) internal {
        assembly ("memory-safe") {
            tstore(CURRENT_MODULE_SLOT, module)
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
    /// @notice A module becomes the current module upon being called.
    /// @notice In a callback (using `multicallFromModule`), the current module is set back to the previous current
    /// module at the end of the calls.
    function currentModule() public view returns (address module) {
        assembly ("memory-safe") {
            module := tload(CURRENT_MODULE_SLOT)
        }
    }

    /* EXTERNAL */

    /// @notice Executes a series of calls to modules.
    /// @dev Locks the initiator so that the sender can be identified by modules.
    /// @param bundle The ordered array of calldata to execute.
    function multicall(Call[] calldata bundle) external payable {
        require(initiator() == address(0), ErrorsLib.AlreadyInitiated());

        setInitiator(msg.sender);

        _multicall(bundle);

        setInitiator(address(0));
    }

    /// @notice Executes a series of calls to modules.
    /// @dev Useful during callbacks.
    /// @dev Can only be called by the current module.
    /// @param bundle The ordered array of calldata to execute.
    function multicallFromModule(Call[] calldata bundle) external {
        require(msg.sender == currentModule(), ErrorsLib.UnauthorizedSender());
        _multicall(bundle);
    }

    /* INTERNAL */

    /// @notice Executes a series of calls to modules.
    function _multicall(Call[] calldata bundle) internal {
        address previousModule = currentModule();
        for (uint256 i; i < bundle.length; ++i) {
            address module = bundle[i].to;
            setCurrentModule(module);
            (bool success, bytes memory returnData) = module.call{value: bundle[i].value}(bundle[i].data);
            if (!success) ModuleLib.lowLevelRevert(returnData);
        }
        setCurrentModule(previousModule);
    }
}
