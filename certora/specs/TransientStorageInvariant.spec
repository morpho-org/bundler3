// SPDX-License-Identifier: GPL-2.0-or-later

methods {
    function initiator() external returns address envfree;
    function reenterHash() external returns bytes32 envfree;
}

//Check that transient storage is nullified on each entrypoint.
invariant transientStorageNullified()
    initiator() == 0 && reenterHash() == to_bytes32(0);
