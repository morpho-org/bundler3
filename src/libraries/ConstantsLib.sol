// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @dev Slot where the 0-indexed bundle hash is stored. The n-th hash is stored at slot HASH_0_SLOT + n.
/// @dev Equal to keccak256("Morpho Bundler Bundle Hash 0 Slot"), stored as hex literal so it can be used in assembly.
bytes32 constant BUNDLE_HASH_0_SLOT = 0x92153f00b3943eedd2c7da8b93b52be03101d98a11a8a68de75c574172b6241a;
