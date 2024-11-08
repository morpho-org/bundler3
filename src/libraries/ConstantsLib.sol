// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @dev Transient storage slot for the bundler's current initiator.
/// @dev Keeps track of the bundler's latest bundle initiator.
/// @dev Also prevents interacting with the bundler outside of an initiated execution context.
/// @dev Equal to keccak256("Morpho Bundler Hub Initiator Slot"), stored as hex literal so it can be used in assembly.
bytes32 constant INITIATOR_SLOT = 0x509a5c1e0b8e41b0cb1986d077b996dfb7c437dac87331e037e8504619fa6315;

/// @dev Slot where the currently called bundler is transiently stored.
/// @dev Equal to keccak256("Morpho Bundler Current Bundler Slot"), stored as hex literal so it can be used in assembly.
bytes32 constant CURRENT_BUNDLER_SLOT = 0xc00b2bf86408d5c066f9552a19ac231a6676439bd471e6f61fe49427863347e0;

/// @dev Slot where the index of the current bundle hash is stored.
/// @dev Equal to keccak256("Morpho Bundler Current Bundle Hash Index Slot"), stored as hex literal so it can be used in
/// assembly.
bytes32 constant CURRENT_BUNDLE_HASH_INDEX_SLOT = 0x9d9603a2ed12b7982342506cf9802a54e421528ff8d9f7c07c8a7eb4fb06565a;

/// @dev Slot where the 0-indexed bundle hash is stored. The n-th hash is stored at slot HASH_0_SLOT + n.
/// @dev Equal to keccak256("Morpho Bundler Bundle Hash 0 Slot"), stored as hex literal so it can be used in assembly.
bytes32 constant BUNDLE_HASH_0_SLOT = 0x92153f00b3943eedd2c7da8b93b52be03101d98a11a8a68de75c574172b6241a;
