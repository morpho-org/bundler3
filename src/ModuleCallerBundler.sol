// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.24;

import {IMorphoBundlerModule} from "./interfaces/IMorphoBundlerModule.sol";
import {IModuleCallerBundler} from "./interfaces/IModuleCallerBundler.sol";
import {BaseBundler} from "./BaseBundler.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {CURRENT_MODULE_SLOT} from "./libraries/ConstantsLib.sol";

/// @title ModuleCallerBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Bundler contract managing calls to external bundler module contracts
abstract contract ModuleCallerBundler is BaseBundler, IModuleCallerBundler {

    /* EXTERNAL */

    /// @inheritdoc IModuleCallerBundler
    function callModule(address module, bytes calldata data, uint value) external payable protected {
        address previousModule = currentModule();
        setCurrentModule(module);
        IMorphoBundlerModule(module).morphoBundlerModuleCall{value:value}(initiator(), data);
        setCurrentModule(previousModule);
    }

    /// @inheritdoc IModuleCallerBundler
    function onCallback(bytes calldata data) external payable {
        require(msg.sender == currentModule(), ErrorsLib.UNAUTHORIZED_SENDER);
        _multicall(abi.decode(data, (bytes[])));
    }

    /* INTERNAL */

    /// @notice Returns the bundler module currently being called.
    function currentModule() public view returns (address module) {
        assembly ("memory-safe") {
            module := tload(CURRENT_MODULE_SLOT)
        }
    }

    /// @notice Set the bundler module that is about to be called.
    function setCurrentModule(address module) internal {
        assembly ("memory-safe") {
            tstore(CURRENT_MODULE_SLOT,module)
        }
    }

    /// @inheritdoc BaseBundler
    function _isSenderAuthorized() internal view virtual override returns (bool) {
        return super._isSenderAuthorized() || msg.sender == currentModule();
    }
}
