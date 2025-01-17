// SPDX-License-Identifier: GPL-2.0-or-later

methods{
    function _.supplyTo(address, address, uint256) external => HAVOC_ECF;
    function _.approve(address, uint256) external => DISPATCHER(true);
    function _.baseToken() external => mockBaseToken() expect address;
}

persistent ghost address lastErc20;
persistent ghost bool erc20Changed;

function mockBaseToken() returns address {
    address erc20;
    if (erc20 != lastErc20) {
        erc20Changed = true;
        lastErc20 = erc20;
    }
    return erc20;
}

// Check that the instance's allowance is set to zero for the adapter.
rule compoundV3RepayAllowanceNull(env e, address instance, uint256 amount, address onBehalf) {
    compoundV3Repay(e, instance, amount, onBehalf);
    assert !erc20Changed => lastErc20.allowance(e, currentContract, instance) == 0;
}