// SPDX-License-Identifier: GPL-2.0-or-later

methods{
    function _.repayBorrowBehalf(address, uint256) external => HAVOC_ECF;
    function _.approve(address, uint256) external => DISPATCHER(true);
    function _.underlying() external => PER_CALLEE_CONSTANT;
}

// Check that the token's allowance is set to zero for the adapter.
rule compoundV2RepayErc20AllowanceNull(env e,address token, uint256 amount, address onBehalf) {
    compoundV2RepayErc20(e, token, amount, onBehalf);
    assert token.underlying(e).allowance(e, currentContract, token) == 0;
}
