// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @dev Transient storage slot for the bundler's current initiator.
/// @dev Keeps track of the bundler's latest bundle initiator.
/// @dev Also prevents interacting with the bundler outside of an initiated execution context.
/// @dev Equal to keccak256("Morpho Bundler Hub Initiator Slot"), stored as hex literal so it can be used in assembly.
bytes32 constant INITIATOR_SLOT = 0x509a5c1e0b8e41b0cb1986d077b996dfb7c437dac87331e037e8504619fa6315;

/// @dev Slot where the currently called bundler bundler is transiently stored.
/// @dev Equal to keccak256("Morpho Bundler Current Bundler Slot"), stored as hex literal so it can be used in assembly.
bytes32 constant CURRENT_BUNDLER_SLOT = 0xc00b2bf86408d5c066f9552a19ac231a6676439bd471e6f61fe49427863347e0;
