// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

  /// @dev Transient storage slot for the bundler's current initiator.
  /// @dev Keeps track of the bundler's latest bundle initiator.
  /// @dev Also prevents interacting with the bundler outside of an initiated execution context.
  /// @dev Equal to keccak256("Morpho Bundler Initiator Slot"), stored as hex literal so it can be used in assembly.
bytes32 constant INITIATOR_SLOT = 
0x33a59cbcc71c90d612d5afca82f27022cd1319f49b953968504d8209c045bd1f;