// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @notice Struct containing all the data needed to make a call.
struct Call {
    address to;
    bytes data;
    uint256 value;
}
