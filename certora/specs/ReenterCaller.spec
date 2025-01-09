// SPDX-License-Identifier: GPL-2.0-or-later

using Bundler as Bundler;
using ParaswapAdapter as ParaswapAdapter;

// True when the function Bundler.reenter has been called.
persistent ghost bool reenterCalled {
    init_state axiom reenterCalled == false;
}

hook CALL(uint g, address addr, uint value, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    if (selector == sig:Bundler.reenter(Bundler.Call[]).selector) {
        reenterCalled = true;
    }
}

// Asses wether or not a given selector may reenter the bundler.
definition isAuthorizedToReenter(uint32 selector) returns bool =
    selector == sig:onMorphoSupply(uint256, bytes).selector ||
    selector == sig:onMorphoSupplyCollateral(uint256, bytes).selector ||
    selector == sig:onMorphoRepay(uint256, bytes).selector ||
    selector == sig:onMorphoFlashLoan(uint256, bytes).selector ||
    selector == sig:ParaswapAdapter.sell(address, bytes, address, address, bool, ParaswapAdapter.Offsets, address).selector ||
    selector == sig:ParaswapAdapter.buy(address, bytes, address, address, uint256,  ParaswapAdapter.Offsets, address).selector ||
    selector == sig:ParaswapAdapter.buyMorphoDebt(address, bytes, address, ParaswapAdapter.MarketParams, ParaswapAdapter.Offsets, address, address).selector;


// Check that Bundler.reenter can be called only by authorized adapters.
rule reenterSafe(method f, env e, calldataarg data) {
    // Avoid failing vacuity checks, as it requires to explicitely show that reenterCalled holds.
    require !reenterCalled;
    f(e, data);
    assert reenterCalled =>  isAuthorizedToReenter(f.selector);
}
