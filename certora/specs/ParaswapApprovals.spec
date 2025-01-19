// SPDX-License-Identifier: GPL-2.0-or-later

using ERC20Mock as ERC20Mock;
using ERC20NoRevert as ERC20NoRevert;
using ERC20USDT as ERC20USDT;

methods{
    function _.set(bytes memory, uint256 offset, uint256 value) internal => setData(offset, value);
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

function setData(uint256 offset, uint256 value) returns uint256 {
    havoc data assuming data@new[offset] == value;
    return data[offset];
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
    require srcToken != ERC20USDT;
    currentContract.buy(e, augustus, callData, srcToken, destToken, newDestAmount, offsets, receiver);
    assert srcToken.allowance(e, currentContract, augustus) == 0;
}
