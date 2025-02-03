// SPDX-License-Identifier: GPL-2.0-or-later

using ERC20Mock as ERC20Mock;
using ERC20NoRevert as ERC20NoRevert;
using ERC20USDT as ERC20USDT;

methods{
    function _.set(bytes memory, uint256 offset, uint256) internal => setData(offset) expect void;
    function _.get(bytes memory, uint256 offset) internal => getData(offset) expect uint256;
    function _.isValidAugustus(address) external => NONDET;
    function _.approve(address, uint256) external => DISPATCHER(true);
    function _.transfer(address, uint256) external => DISPATCHER(true);
    function _.balanceOf(address) external => DISPATCHER(true);
}

persistent ghost mapping(uint256 => uint256) data;

function getData(uint256 offset) returns uint256 {
    return data[offset];
}

function setData(uint256 offset) {
    havoc data;
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
        f.selector != sig:buy(address, bytes ,address, address, uint256, ParaswapAdapter.Offsets, address).selector &&
        f.selector != sig:buyMorphoDebt(address, bytes , address, ParaswapAdapter.MarketParams, ParaswapAdapter.Offsets, address, address).selector &&
        f.selector != sig:sell(address, bytes, address, address, bool, ParaswapAdapter.Offsets, address).selector
}{
    // Set up inital state.
    require !approveCalled;
    f@withrevert(e, args);
    assert !lastReverted => !approveCalled;
}

// Check that the augustus's allowance is set to zero for the adapter upon calling buy.
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

// Check that the augustus's allowance is set to zero for the adapter upon calling sell.
rule sellAllowanceNull(
    env e,
    address augustus,
    bytes callData,
    address srcToken,
    address destToken,
    bool sellEntireBalance,
    ParaswapAdapter.Offsets offsets,
    address receiver
) {
    require augustus != currentContract;
    currentContract.sell(e, augustus, callData, srcToken, destToken, sellEntireBalance, offsets, receiver);
    assert srcToken.allowance(e, currentContract, augustus) == 0;
}
