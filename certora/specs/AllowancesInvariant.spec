// SPDX-License-Identifier: GPL-2.0-or-later

using GeneralAdapter1 as GeneralAdapter1;
using EthereumGeneralAdapter1 as EthereumGeneralAdapter1;
using ParaswapAdapter as ParaswapAdapter;

methods {
    function _.approve(address token, address spender, uint256 amount) external => summaryApprove(calledContract, spender, amount) expect bool;

    // We need a summary because it does an unresolved call.
    // Sound because the data is "".
    function _.sendValue(address recipient, uint256 amount) internal => CONSTANT;

    // We need a summary because it does an unresolved call.
    // Sound because the selector is "reenter(bytes calldata)".
    function _.reenterBundler3(bytes calldata data) internal => CONSTANT;

    unresolved external in _._ => DISPATCH [] default ASSERT_FALSE;
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

definition isTrusted(address spender) returns bool =
    spender == GeneralAdapter1.MORPHO ||
    spender == EthereumGeneralAdapter1.MORPHO ||
    spender == EthereumGeneralAdapter1.MORPHO_WRAPPER ||
    spender == EthereumGeneralAdapter1.WST_ETH;

invariant allowancesAreReset(address token, address spender)
    isTrusted(spender) || changedAllowances[token][spender] == 0
    // The invariant doesn't hold with the following functions.
    filtered {
      f -> f.selector != sig:ParaswapAdapter.buy(address, bytes ,address, address, uint256, ParaswapAdapter.Offsets, address).selector &&
           f.selector != sig:ParaswapAdapter.buyMorphoDebt(address, bytes , address, ParaswapAdapter.MarketParams, ParaswapAdapter.Offsets, address, address).selector &&
           f.selector != sig:ParaswapAdapter.sell(address, bytes, address, address, bool, ParaswapAdapter.Offsets, address).selector
    }
