// SPDX-License-Identifier: GPL-2.0-or-later

methods{
    function _.repay(address, uint256, uint256, address) external => HAVOC_ECF;
    function _.approve(address, uint256) external => DISPATCHER(true);
}

// True when `approve` has been called.
persistent ghost bool approveCalled;

hook CALL(uint g, address addr, uint value, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
     // Hardcoding the approve(addres, uint256) ABI selector with 0x095ea7b3 avoids an error due to the method not being found.
    if (selector == 0x095ea7b3) {
       approveCalled = true;
    }
}

rule allowancesNotChanged(env e, method f, calldataarg args) filtered {
    // Do not check view functions or the `receive` function, which is safe as it is empty.
    f -> !f.isView && !f.isFallback &&
         f.selector != sig:aaveV3OptimizerRepay(address, uint256, address).selector
}{
    // Set up inital state.
    require !approveCalled;
    f@withrevert(e, args);
    assert !lastReverted => !approveCalled;
}

// Check that the optimizer's allowance is set to zero for the adapter.
rule aaveV3OptimizerRepayAllowanceNull(env e, address underlying, uint256 amount, address onBehalf) {
    aaveV3OptimizerRepay(e, underlying, amount, onBehalf);
    assert underlying.allowance(e, currentContract, currentContract.AAVE_V3_OPTIMIZER) == 0;
}
