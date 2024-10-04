// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {TRANSIENT_VARIABLES_PREFIX} from "./ConstantsLib.sol";
import {ErrorsLib} from "./ErrorsLib.sol";
import {BytesLib} from "./BytesLib.sol";

/// @title VariablesLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing transient variable manipulation.
library VariablesLib {
    /// @notice Set variable `name` to `value` in transient storage.
    function set(bytes32 name, uint256 value) internal {
        require(name != "", ErrorsLib.NULL_VARIABLE_NAME);
        bytes32 slot = getSlot(name);
        assembly ("memory-safe") {
            tstore(slot, value)
        }
    }

    /// @notice Get variable `name` from transient storage.
    function get(bytes32 name) internal view returns (uint256 value) {
        bytes32 slot = getSlot(name);
        assembly ("memory-safe") {
            value := tload(slot)
        }
    }

    /// @notice Get transient storage slot for variable `name`.
    function getSlot(bytes32 name) internal pure returns (bytes32 slot) {
        slot = keccak256(abi.encode(TRANSIENT_VARIABLES_PREFIX, name));
    }
}
