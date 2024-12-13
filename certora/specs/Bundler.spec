// SPDX-License-Identifier: GPL-2.0-or-later

using Bundler as Bundler;

methods {
    function initiator() external returns address envfree;
    function reenterHash() external returns bytes32 envfree;
}

// True when `mutlicall` has been called.
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

// Check that reentering is possible if and only if `multicall` is called.
rule reenterAfterMulticall(method f, env e, calldataarg data) {

    // Set up the initial state.
    require !multicallCalled;
    require !reenterCalled;
    // Safe require since it's transiently sotred so it's nullified after a transfer call.
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

// Check that initiator is reset after a multicall.
rule zeroInitiatorRevertsMulticall(env e, Bundler.Call[] bundle) {
    address initiatorBefore = initiator();
    bytes32 reenterHashBefore = reenterHash();

    multicall@withrevert(e, bundle);

    assert initiatorBefore != 0 => lastReverted;
    assert reenterHashBefore != to_bytes32(0) => lastReverted;
}

// Check that the reenterHash is non zero before reentering a multicall.
rule zeroReenterHashReverts(env e, Bundler.Call[] bundle) {
    bytes32 reenterHashBefore = reenterHash();

    reenter@withrevert(e, bundle);

    assert reenterHashBefore == to_bytes32(0) => lastReverted;
}

rule initiatorZeroAfterMulticall(env e, Bundler.Call[] bundle) {
    // Safe require as implementation would revert, see rule zeroInitiatorRevertsMulticall.
    require initiator() == 0;

    require reenterHash() == to_bytes32(0);

    multicall(e, bundle);

    assert initiator() == 0;
    assert reenterHash() == to_bytes32(0);

    // Sanity check to ensure the rule is not trivially true.
    satisfy bundle.length != 0;
}
