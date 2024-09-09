// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {IMorphoBundlerModule} from "../interfaces/IMorphoBundlerModule.sol";

/// @title BaseMorphoBundlerModule
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Morpho Bundler Module abstract contract. Enforces caller verification.
abstract contract BaseMorphoBundlerModule is IMorphoBundlerModule {
    address public immutable MORPHO_BUNDLER;

    constructor(address morphoBundler) {
        MORPHO_BUNDLER = morphoBundler;
    }

    /// @notice Wrapper that receives call from the Morpho Bundler.
    /// @dev Checks that msg.sender is the Morpho Bundler so that initiator value can be trusted.
    function morphoBundlerModuleCall(address initiator, bytes calldata data) external payable {
        require(msg.sender == MORPHO_BUNDLER, ErrorsLib.UNAUTHORIZED_SENDER);
        _morphoBundlerModuleCall(initiator, data);
    }

    /// @notice Receives a call from the Morpho Bundler.
    /// @dev Must be implemented by inheriting contracts.
    function _morphoBundlerModuleCall(address initiator, bytes calldata data) internal virtual;
}
