// SPDX-License-Identifier: GPL-2.0-or-later

using ERC20Mock as ERC20Mock;
using ERC20NoRevert as ERC20NoRevert;
using ERC20USDT as ERC20USDT;

methods{
    unresolved external in currentContract._ =>
        DISPATCH [ ERC20Mock.approve(address, uint256),
                   ERC20NoRevert.approve(address, uint256),
                   ERC20USDT.approve(address, uint256),
                   ERC20Mock.balanceOf(address),
                   ERC20NoRevert.balanceOf(address),
                   ERC20USDT.balanceOf(address) ] default NONDET;
}

// Check that the augustus's allowance is set to zero for the adapter.
rule buyAllowanceNull(
    env e,
    address augustus,
    bytes callData,
    address srcToken,
    address destToken,
    uint256 newDestAmount,
    ParaswapAdapter.Offsets offsets,
    address receiver
) {
    require augustus != currentContract;
    currentContract.buy(e, augustus, callData, srcToken, destToken, newDestAmount, offsets, receiver);
    assert srcToken.allowance(e, currentContract, augustus) == 0;
}
