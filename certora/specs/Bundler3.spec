// SPDX-License-Identifier: GPL-2.0-or-later

import "TransientStorageInvariant.spec";

using Bundler3 as Bundler3;

methods {
    function initiator() external returns address envfree;
    function reenterHash() external returns bytes32 envfree;
}

// True when `multicall` has been called.
persistent ghost bool multicallCalled;

// True when `reenter` has been called.
persistent ghost bool reenterCalled;

hook CALL(uint g, address addr, uint value, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    if (selector == sig:multicall(Bundler3.Call[]).selector) {
       multicallCalled = true;
    } else if (selector == sig:reenter(Bundler3.Call[]).selector) {
       reenterCalled = true;
    }
}

// Check that reentering is possible only if `multicall` has been called.
rule reenterAfterMulticall(method f, env e, calldataarg data) {

    // Set up the initial state.
    require !multicallCalled;
    require !reenterCalled;

    requireInvariant transientStorageNullified();

    // Capture the first method call which is not performed with a CALL opcode.
    if (f.selector == sig:multicall(Bundler3.Call[]).selector) {
       multicallCalled = true;
    } else if (f.selector == sig:reenter(Bundler3.Call[]).selector) {
       reenterCalled = true;
    }

    f@withrevert(e,data);

    // Avoid failing vacuity checks, either the proposition is true or the execution reverts.
    assert !lastReverted => (reenterCalled => multicallCalled);
}

// Check that non zero initiator will trigger a revert upon a multicall.
rule nonZeroInitiatorRevertsMulticall(env e, Bundler3.Call[] bundle) {
    address initiatorBefore = initiator();

    multicall@withrevert(e, bundle);

    assert initiatorBefore != 0 => lastReverted;
}

// Check that a null reenterHash will trigger a revert upon reentering Bundler3.
rule zeroReenterHashRevertsReenter(env e, Bundler3.Call[] bundle) {
    bytes32 reenterHashBefore = reenterHash();

    reenter@withrevert(e, bundle);

    assert reenterHashBefore == to_bytes32(0) => lastReverted;
}
