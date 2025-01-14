// SPDX-License-Identifier: GPL-2.0-or-later

using Bundler3 as Bundler3;
using ParaswapAdapter as ParaswapAdapter;

// True when the function Bundler3.reenter has been called.
persistent ghost bool reenterCalled {
    init_state axiom reenterCalled == false;
}

hook CALL(uint g, address addr, uint value, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    if (selector == sig:Bundler3.reenter(Bundler3.Call[]).selector) {
        reenterCalled = true;
    }
}

// Whether or not a given selector may reenter Bundler3.
definition isAuthorizedToReenter(uint32 selector) returns bool =
    selector == sig:onMorphoSupply(uint256, bytes).selector ||
    selector == sig:onMorphoSupplyCollateral(uint256, bytes).selector ||
    selector == sig:onMorphoRepay(uint256, bytes).selector ||
    selector == sig:onMorphoFlashLoan(uint256, bytes).selector ||
    selector == sig:ParaswapAdapter.sell(address, bytes, address, address, bool, ParaswapAdapter.Offsets, address).selector ||
    selector == sig:ParaswapAdapter.buy(address, bytes, address, address, uint256,  ParaswapAdapter.Offsets, address).selector ||
    selector == sig:ParaswapAdapter.buyMorphoDebt(address, bytes, address, ParaswapAdapter.MarketParams, ParaswapAdapter.Offsets, address, address).selector;

// Check that, from the adapters in this repository, only a known set of functions can call Bundler3.reenter directly.
// Note that calling Bundler3.reenter indirectly (i.e. through a third contract) is prevented by the reenterHash mechanism.
// Also note that `multicall` can call other adapters than the ones defined in this repository.
rule reenterSafe(method f, env e, calldataarg data) {
    // Avoid failing vacuity checks, as it requires to explicitely show that reenterCalled holds.
    require !reenterCalled;
    f(e, data);
    assert reenterCalled => isAuthorizedToReenter(f.selector);
}
