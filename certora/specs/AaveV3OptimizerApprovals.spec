// SPDX-License-Identifier: GPL-2.0-or-later

methods{
    function _.repay(address, uint256, uint256, address) external => HAVOC_ECF;
    function _.approve(address, uint256) external => DISPATCHER(true);
}

// Check that the optimizer's allowance is set to zero for the adapter.
rule aaveV3OptimizerRepayAllowanceNull(env e,address underlying, uint256 amount, address onBehalf) {
    aaveV3OptimizerRepay(e, underlying, amount, onBehalf);
    assert underlying.allowance(e, currentContract, currentContract.AAVE_V3_OPTIMIZER) == 0;
}