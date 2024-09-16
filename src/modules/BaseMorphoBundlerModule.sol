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
    modifier protected() {
        require(msg.sender == MORPHO_BUNDLER, ErrorsLib.UNAUTHORIZED_SENDER);
        _;
    }

    /* EXTERNAL */

    /// @notice Re-dispatches all calls to itself.
    function onMorphoBundlerCall(bytes memory data) external payable {
        assembly {
            let success := delegatecall(gas(), address(), add(data, 32), mload(data), 0, 0)
            returndatacopy(0, 0, returndatasize())

            if iszero(success) { revert(0, returndatasize()) }
            return(0, returndatasize())
        }
    }

    /* INTERNAL */

    /// @notice Returns the current initiator stored in the bundler.
    function initiator() internal view returns (address) {
        return IInitiatorStore(MORPHO_BUNDLER).initiator();
    }
}
