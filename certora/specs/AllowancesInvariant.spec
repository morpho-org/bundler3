// SPDX-License-Identifier: GPL-2.0-or-later

using GeneralAdapter1 as GeneralAdapter1;
using EthereumGeneralAdapter1 as EthereumGeneralAdapter1;

methods {
    function _.approve(address spender, uint256 amount)  external => summaryApprove(spender, amount) expect bool;
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

// True when `approve` has been called.
persistent ghost bool approveCalled {
    init_state axiom approveCalled == false;
}

// True when `approve` has been called with zero allowance.
persistent ghost bool lastApproveNull {
    init_state axiom lastApproveNull == false;
}

// True when `approve` has been called with a trusted spender.
persistent ghost bool trustedSpender {
    init_state axiom trustedSpender == false;
}


definition isKnownImmutable (address spender) returns bool =
    spender == GeneralAdapter1.MORPHO ||
    spender == EthereumGeneralAdapter1.MORPHO ||
    spender == EthereumGeneralAdapter1.MORPHO_WRAPPER ||
    spender == EthereumGeneralAdapter1.WST_ETH;

function summaryApprove(address spender, uint256 amount) returns bool {
    if (!isKnownImmutable(spender)) {
        approveCalled = true;
        lastApproveNull = amount == 0;
    } else {
        trustedSpender = true;
    }
    bool res;
    return res;
}

invariant AllowancesIsolated()
    !approveCalled || lastApproveNull || trustedSpender;
