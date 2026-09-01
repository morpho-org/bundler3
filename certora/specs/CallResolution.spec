// SPDX-License-Identifier: GPL-2.0-or-later

methods {
    // The unresolved call should not to be reachable.
    function _.approve(address spender, uint256 amount) external => ASSERT_FALSE;

    // Force call resolution to reach the ASSERT_FALSE summary introduced before.
    unresolved external in currentContract.doUnresolvedCall(bytes) => DISPATCH [ _.approve(address, uint256) ] default NONDET;
}

rule canSummarize(env e, bytes data){

    doUnresolvedCall@withrevert(e, data);
    // The verification should reach the ASSERT_FALSE summary and fail.

    // Dummy non trivial goal.
    satisfy !lastReverted;
}
