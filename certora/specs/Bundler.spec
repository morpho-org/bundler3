// SPDX-License-Identifier: GPL-2.0-or-later

using Bundler as Bundler;

methods {
    function initiator() external returns address envfree;
    function reenterHash() external returns bytes32 envfree;
}

// True when `multicall` has been called.
persistent ghost bool multicallCalled;

// True when `reenter` has been called.
persistent ghost bool reenterCalled;

hook CALL(uint g, address addr, uint value, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    if (selector == sig:multicall(Bundler.Call[]).selector) {
       multicallCalled = true;
    } else if (selector == sig:reenter(Bundler.Call[]).selector) {
       reenterCalled = true;
    }
}

// Check that reentering is possible only if `multicall` has been called.
rule reenterAfterMulticall(method f, env e, calldataarg data) {

    // Set up the initial state.
    require !multicallCalled;
    require !reenterCalled;
    // Safe require since it's transiently stored so it's nullified after a reentrant call.
    require reenterHash() == to_bytes32(0);

    // Capture the first method call which is not performed with a CALL opcode.
    if (f.selector == sig:multicall(Bundler.Call[]).selector) {
       multicallCalled = true;
    } else if (f.selector == sig:reenter(Bundler.Call[]).selector) {
       reenterCalled = true;
    }

    f@withrevert(e,data);

    // Avoid failing vacuity checks, either the proposition is true or the execution reverts.
    assert !lastReverted => (reenterCalled => multicallCalled);
}

// Check that non zero initiator will trigger a revert upon a multicall.
rule zeroInitiatorRevertsMulticall(env e, Bundler.Call[] bundle) {
    address initiatorBefore = initiator();

    multicall@withrevert(e, bundle);

    assert initiatorBefore != 0 => lastReverted;
}

// Check that a null reenterHash will trigger a revert upon reentering the bundler.
rule zeroReenterHashReverts(env e, Bundler.Call[] bundle) {
    bytes32 reenterHashBefore = reenterHash();

    reenter@withrevert(e, bundle);

    assert reenterHashBefore == to_bytes32(0) => lastReverted;
}
// Check that transient storage is nullified after a multicall.
rule initiatorZeroAfterMulticall(env e, Bundler.Call[] bundle) {
    require reenterHash() == to_bytes32(0);

    multicall(e, bundle);

    assert initiator() == 0;
    assert reenterHash() == to_bytes32(0);
}
