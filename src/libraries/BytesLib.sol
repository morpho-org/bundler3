// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./ErrorsLib.sol" as ErrorsLib;

/// @title BytesLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing bytes manipulation.
library BytesLib {
    /// @notice Read 32 bytes at offset `offset` of memory bytes `data`.
    function get(bytes memory data, uint256 offset) internal pure returns (uint256 currentValue) {
        require(offset <= data.length - 32, ErrorsLib.InvalidOffset(offset));
        assembly {
            currentValue := mload(add(32, add(data, offset)))
        }
    }

    /// @notice Write `value` at offset `offset` of memory bytes `data`.
    function set(bytes memory data, uint256 offset, uint256 value) internal pure {
        require(offset <= data.length - 32, ErrorsLib.InvalidOffset(offset));
        assembly ("memory-safe") {
            mstore(add(32, add(data, offset)), value)
        }
    }
}
