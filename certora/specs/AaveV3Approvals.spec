// SPDX-License-Identifier: GPL-2.0-or-later

methods{
    function _.repay(address, uint256, uint256, address) external => HAVOC_ECF;
    function _.approve(address, uint256) external => DISPATCHER(true);
}

// Check that the pools's allowance is set to zero for the adapter.
rule aaveV3RepayAllowanceNull(env e,address token, uint256 amount, uint256 interestRateMode, address onBehalf) {
    aaveV3Repay(e, token, amount, interestRateMode, onBehalf);
    assert token.allowance(e, currentContract, currentContract.AAVE_V3_POOL) == 0;
}