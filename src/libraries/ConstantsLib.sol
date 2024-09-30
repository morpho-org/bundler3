// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @dev The default value of the initiator of the multicall transaction is not the address zero to save gas.
address constant UNSET_INITIATOR = address(1);

/// @dev Slot where currently called bundler module is transiently stored.
/// @dev Equal to keccak256("Morpho Bundler Current Module Slot"), stored as hex literal so it can be used in assembly.
bytes32 constant CURRENT_MODULE_SLOT = 0x4a208b9e5a8db61bf46ae647a7eb221065bc0d8fcb9958db28b558743ea1472d;

bytes32 constant TRANSIENT_VARIABLES_PREFIX = "morpho-bundler-variables";
