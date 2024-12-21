// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "./ErrorsLib.sol";

/// @custom:security-contact security@morpho.org
/// @notice Library exposing bytes manipulation.
library BytesLib {
    /// @notice Reads 32 bytes at offset `offset` of memory bytes `data`.
    function get(bytes memory data, uint256 offset) internal pure returns (uint256 currentValue) {
        require(offset <= data.length - 32, ErrorsLib.InvalidOffset());
        assembly ("memory-safe") {
            currentValue := mload(add(32, add(data, offset)))
        }
    }

    /// @notice Writes `value` at offset `offset` of memory bytes `data`.
    function set(bytes memory data, uint256 offset, uint256 value) internal pure {
        require(offset <= data.length - 32, ErrorsLib.InvalidOffset());
        assembly ("memory-safe") {
            mstore(add(32, add(data, offset)), value)
        }
    }
}
