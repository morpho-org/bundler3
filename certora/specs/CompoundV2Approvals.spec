// SPDX-License-Identifier: GPL-2.0-or-later

methods{
    function _.repayBorrowBehalf(address, uint256) external => HAVOC_ECF;
    function _.approve(address, uint256) external => DISPATCHER(true);
    function _.underlying() external => mockUnderlying() expect address;
}

persistent ghost address lastErc20;
persistent ghost bool erc20Changed;

function mockUnderlying() returns address {
    address erc20;
    if (erc20 != lastErc20) {
        erc20Changed = true;
        lastErc20 = erc20;
    }
    return erc20;
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
         f.selector != sig:compoundV2RepayErc20(address, uint256, address).selector
}{
    // Set up inital state.
    require !approveCalled;
    f(e, args);
    assert !approveCalled;
}

// Check that the token's allowance is set to zero for the adapter.
rule compoundV2RepayErc20AllowanceNull(env e,address token, uint256 amount, address onBehalf) {
    compoundV2RepayErc20(e, token, amount, onBehalf);
    assert !erc20Changed => lastErc20.allowance(e, currentContract, token) == 0;
}
