// SPDX-License-Identifier: GPL-2.0-or-later

using Bundler as Bundler;
using ParaswapAdapter as ParaswapAdapter;

persistent ghost bool reenterNotCalled {
    init_state axiom reenterNotCalled == true;
}

hook CALL(uint g, address addr, uint value, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    if (selector == sig:Bundler.reenter(Bundler.Call[]).selector) {
       reenterNotCalled = false;
    }
}

// Check that Bundler.reenter can be called only by authorized adapters.
rule reenterSafe(method f, env e, calldataarg data) {
    // Check wether or not f is authorized to reenter.
    bool authorizedMethod = f.selector == sig:onMorphoSupply(uint256, bytes).selector ||
        f.selector == sig:onMorphoSupplyCollateral(uint256, bytes).selector ||
        f.selector == sig:onMorphoRepay(uint256, bytes).selector ||
        f.selector == sig:onMorphoFlashLoan(uint256, bytes).selector ||
        f.selector == sig:ParaswapAdapter.sell(address, bytes, address, address, bool, ParaswapAdapter.Offsets, address).selector ||
        f.selector == sig:ParaswapAdapter.buy(address, bytes, address, address, uint256,  ParaswapAdapter.Offsets, address).selector ||
        f.selector == sig:ParaswapAdapter.buyMorphoDebt(address, bytes, address, ParaswapAdapter.MarketParams, ParaswapAdapter.Offsets, address, address).selector;

    require reenterNotCalled;
    f(e, data);
    assert !reenterNotCalled => authorizedMethod;
}
