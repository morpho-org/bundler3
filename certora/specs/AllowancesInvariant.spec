// SPDX-License-Identifier: GPL-2.0-or-later

using GeneralAdapter1 as GeneralAdapter1;
using EthereumGeneralAdapter1 as EthereumGeneralAdapter1;
using ParaswapAdapter as ParaswapAdapter;
using MockAugustus as MockAugustus;
using ERC20Mock as ERC20Mock;

methods {
    function _.approve(address token, address spender, uint256 amount) external => summaryApprove(calledContract, spender, amount) expect bool ALL;

    // We need a summary because it does an unresolved call.
    // Sound because the data is "".
    function _.sendValue(address recipient, uint256 amount) internal => CONSTANT;

    // We need a summary because it does an unresolved call.
    // Sound because the selector is "reenter(bytes calldata)".
    function _.reenterBundler3(bytes calldata data) internal => CONSTANT;

    function _.isValidAugustus(address augustus) external => summaryIsValidAugustus(augustus) expect bool;

    unresolved external in MockAugustus._ => DISPATCH(use_fallback=true) [ ERC20Mock.approve(address,uint256) ] default NONDET;
    unresolved external in _._ => DISPATCH(use_fallback=true) [ MockAugustus._ ] default ASSERT_FALSE;
}

// Ghost variable to store changed allowances.
// This models only direct changes in allowances.
persistent ghost mapping (address => mapping (address => uint256)) changedAllowances {
    init_state axiom forall address token. forall address spender. changedAllowances[token][spender] == 0 ;
}

function summaryApprove(address token, address spender, uint256 amount)  returns bool {
    changedAllowances[token][spender] = amount;
    // Safe return value as summaries can't fail.
    return true;
}

function summaryIsValidAugustus(address augustus) returns bool {
    require augustus == MockAugustus;
    return true;
}

definition isTrusted(address spender) returns bool =
    spender == GeneralAdapter1.MORPHO ||
    spender == EthereumGeneralAdapter1.MORPHO ||
    spender == EthereumGeneralAdapter1.MORPHO_WRAPPER ||
    spender == EthereumGeneralAdapter1.WST_ETH;

invariant allowancesAreReset(address token, address spender)
    isTrusted(spender) || changedAllowances[token][spender] == 0;
