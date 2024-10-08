// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {IMorphoBundlerModule} from "./interfaces/IMorphoBundlerModule.sol";
import {IModularBundler} from "./interfaces/IModularBundler.sol";
import {BaseBundler} from "./BaseBundler.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {CURRENT_MODULE_SLOT} from "./libraries/ConstantsLib.sol";

/// @title ModularBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Bundler contract managing calls to external bundler module contracts
abstract contract ModularBundler is BaseBundler, IModularBundler {
    /* EXTERNAL */

    /// @inheritdoc IModularBundler
    function callModule(address module, bytes calldata data, uint256 value) external payable protected {
        address previousModule = currentModule();
        setCurrentModule(module);
        IMorphoBundlerModule(module).onMorphoBundlerCallModule{value: value}(data);
        setCurrentModule(previousModule);
    }

    /// @inheritdoc IModularBundler
    function multicallFromModule(bytes calldata data) external payable {
        require(msg.sender == currentModule(), ErrorsLib.UNAUTHORIZED_SENDER);
        _multicall(abi.decode(data, (bytes[])));
    }

    /* PUBLIC */

    /// @inheritdoc IModularBundler
    function currentModule() public view returns (address module) {
        assembly ("memory-safe") {
            module := tload(CURRENT_MODULE_SLOT)
        }
    }

    /* INTERNAL */

    /// @notice Set the bundler module that is about to be called.
    function setCurrentModule(address module) internal {
        assembly ("memory-safe") {
            tstore(CURRENT_MODULE_SLOT, module)
        }
    }

    /// @inheritdoc BaseBundler
    function _isSenderAuthorized() internal view virtual override returns (bool) {
        return super._isSenderAuthorized() || msg.sender == currentModule();
    }
}
