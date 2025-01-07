// SPDX-License-Identifier: GPL-2.0-or-later

methods {
    function initiator() external returns address envfree;
    function reenterHash() external returns bytes32 envfree;
}

// Check that the transient storage is nullified on each entry-point call: `reenter` can only be called inside of the execution of a `multicall`.
invariant transientStorageNullified()
    initiator() == 0 && reenterHash() == to_bytes32(0);
