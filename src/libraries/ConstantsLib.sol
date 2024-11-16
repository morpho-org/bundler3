// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @dev Transient storage slot for the module's current initiator.
/// @dev Keeps track of the module's latest bundle initiator.
/// @dev Also prevents interacting with the module outside of an initiated execution context.
/// @dev Equal to keccak256("Morpho Bundler Initiator Slot"), stored as hex literal so it can be used in assembly.
bytes32 constant INITIATOR_SLOT = 0x33a59cbcc71c90d612d5afca82f27022cd1319f49b953968504d8209c045bd1f;

/// @dev Slot where the currently called module is transiently stored.
/// @dev Equal to keccak256("Morpho Bundler Current Module Slot"), stored as hex literal so it can be used in assembly.
bytes32 constant CURRENT_MODULE_SLOT = 0x4a208b9e5a8db61bf46ae647a7eb221065bc0d8fcb9958db28b558743ea1472d;

/// @dev Slot where the index of the current bundle hash is stored.
/// @dev Equal to keccak256("Morpho Bundler Current Bundle Hash Index Slot"), stored as hex literal so it can be used in
/// assembly.
bytes32 constant CURRENT_BUNDLE_HASH_INDEX_SLOT = 0x9d9603a2ed12b7982342506cf9802a54e421528ff8d9f7c07c8a7eb4fb06565a;

/// @dev Slot where the 0-indexed bundle hash is stored. The n-th hash is stored at slot HASH_0_SLOT + n.
/// @dev Equal to keccak256("Morpho Bundler Bundle Hash 0 Slot"), stored as hex literal so it can be used in assembly.
bytes32 constant BUNDLE_HASH_0_SLOT = 0x92153f00b3943eedd2c7da8b93b52be03101d98a11a8a68de75c574172b6241a;
