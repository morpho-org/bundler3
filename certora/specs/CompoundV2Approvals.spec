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

// Check that the token's allowance is set to zero for the adapter.
rule compoundV2RepayErc20AllowanceNull(env e,address token, uint256 amount, address onBehalf) {
    compoundV2RepayErc20(e, token, amount, onBehalf);
    assert !erc20Changed => lastErc20.allowance(e, currentContract, token) == 0;
}
