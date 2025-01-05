// SPDX-License-Identifier: GPL-2.0-or-later

methods{
    function _.supplyTo(address, address, uint256) external => HAVOC_ECF;
    function _.approve(address, uint256) external => DISPATCHER(true);
    function _.baseToken() external => PER_CALLEE_CONSTANT;
}

// Check that the instance's allowance is set to zero for the adapter.
rule compoundV3RepayAllowanceNull(env e, address instance, uint256 amount, address onBehalf) {
    compoundV3Repay(e, instance, amount, onBehalf);
    assert instance.baseToken(e).allowance(e, currentContract, instance) == 0;
}
