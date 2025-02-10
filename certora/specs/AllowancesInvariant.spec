// SPDX-License-Identifier: GPL-2.0-or-later

using GeneralAdapter1 as GeneralAdapter1;
using EthereumGeneralAdapter1 as EthereumGeneralAdapter1;
using ParaswapAdapter as ParaswapAdapter;

methods {
    function _.approve(address token, address spender, uint256 amount)  external => summaryApprove(calledContract, spender, amount) expect bool;
    // Aave dispatch
    function _.repay(address, uint256, uint256, address) external => HAVOC_ECF;
    // Compound dispatch
    function _.repayBorrowBehalf(address, uint256) external => HAVOC_ECF;
    function _.underlying() external => mockUnderlying() expect address;
    function _.supplyTo(address, address, uint256) external => HAVOC_ECF;
    function _.baseToken() external => mockBaseToken() expect address;
    // Paraswap dispatch
    function _.set(bytes memory, uint256 offset, uint256) internal => setData(offset) expect void;
    function _.get(bytes memory, uint256 offset) internal => getData(offset) expect uint256;
    function _.isValidAugustus(address) external => NONDET;
    function _.transfer(address, uint256) external => DISPATCHER(true);
    function _.balanceOf(address) external => DISPATCHER(true);
    unresolved external in ParaswapAdapter._ => DISPATCH [ _.approve(address, uint256) ] default ASSERT_FALSE;
}

persistent ghost address lastErc20Underlying;
persistent ghost bool erc20UnderlyingChanged;

function mockUnderlying() returns address {
    address erc20;
    if (erc20 != lastErc20Underlying) {
        erc20UnderlyingChanged = true;
        lastErc20Underlying = erc20;
    }
    return erc20;
}

persistent ghost address lastErc20BaseToken;
persistent ghost bool erc20BaseTokenChanged;

function mockBaseToken() returns address {
    address erc20;
    if (erc20 != lastErc20BaseToken) {
        erc20BaseTokenChanged = true;
        lastErc20BaseToken = erc20;
    }
    return erc20;
}

persistent ghost mapping(uint256 => uint256) data;

function getData(uint256 offset) returns uint256 {
    return data[offset];
}

function setData(uint256 offset) {
    havoc data;
}

// Ghost variable to store changed allowances.
// This models only direct changes in allowances.
// It implies that unresolved external call are assumed to not change allowances except in the ParaswapAdapter, where unresolved calls are forbidden.
persistent ghost mapping (address => mapping (address => uint256)) changedAllowances {
    init_state axiom forall address token. forall address spender. changedAllowances[token][spender] == 0 ;
}

definition isKnownImmutable (address spender) returns bool =
    spender == GeneralAdapter1.MORPHO ||
    spender == EthereumGeneralAdapter1.MORPHO ||
    spender == EthereumGeneralAdapter1.MORPHO_WRAPPER ||
    spender == EthereumGeneralAdapter1.WST_ETH;

function summaryApprove(address token, address spender, uint256 amount)  returns bool {
    if (!isKnownImmutable(spender)) {
        changedAllowances[token][spender] = amount;
    }
    // Safe return value as summaries can't fail.
    return true;
}


invariant AllowancesIsolated()
    forall address token. forall address spender. changedAllowances[token][spender] == 0
    filtered {
      f -> f.selector != sig:ParaswapAdapter.buy(address, bytes ,address, address, uint256, ParaswapAdapter.Offsets, address).selector &&
      f.selector != sig:ParaswapAdapter.buyMorphoDebt(address, bytes , address, ParaswapAdapter.MarketParams, ParaswapAdapter.Offsets, address, address).selector &&
      f.selector != sig:ParaswapAdapter.sell(address, bytes, address, address, bool, ParaswapAdapter.Offsets, address).selector &&
      f.selector != sig:ParaswapAdapter.nativeTransfer(address, uint256).selector
    }
