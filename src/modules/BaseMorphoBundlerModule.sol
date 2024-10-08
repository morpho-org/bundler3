// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {IMorphoBundlerModule} from "../interfaces/IMorphoBundlerModule.sol";
import {IInitiatorStore} from "../interfaces/IInitiatorStore.sol";

/// @title BaseMorphoBundlerModule
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Morpho Bundler Module abstract contract. Enforces caller verification.
abstract contract BaseMorphoBundlerModule is IMorphoBundlerModule {
    address public immutable MORPHO_BUNDLER;

    constructor(address morphoBundler) {
        MORPHO_BUNDLER = morphoBundler;
    }

    /* MODIFIERS */

    /// @dev Prevents a function from being called outside of a bundle context.
    /// @dev Ensures the value of initiator() is correct.
    modifier bundlerOnly() {
        require(msg.sender == MORPHO_BUNDLER, ErrorsLib.UNAUTHORIZED_SENDER);
        _;
    }

    /* EXTERNAL */

    /// @notice Re-dispatches all calls to itself.
    /// @dev If the inheriting module has a single entrypoint it can override this function to save a self-call.
    function onMorphoBundlerCallModule(bytes calldata data) external payable virtual {
        (bool success,) = address(this).delegatecall(data);
        if (!success) {
            assembly ("memory-safe") {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    /* INTERNAL */

    /// @notice Returns the current initiator stored in the bundler.
    function initiator() internal view returns (address) {
        return IInitiatorStore(MORPHO_BUNDLER).initiator();
    }
}
