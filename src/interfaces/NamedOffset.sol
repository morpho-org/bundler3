// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >= 0.7.0;

/// @notice Struct that represents:
/// - a memory offset, together with
/// - a name for the value at that offset
struct NamedOffset {
    bytes32 name;
    uint256 offset;
}
