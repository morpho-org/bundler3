// SPDX-License-Identifier: GPL-2.0-or-later

methods{
    function _.depositFor(address, uint256) external => DISPATCHER(true);
    function _.underlying() external => DISPATCHER(true);
    function _.mint(uint256, address) external  => DISPATCHER(true);
    function _.deposit(uint256, address) external => DISPATCHER(true);
    function _.asset() external => DISPATCHER(true);
    function _.approve(address, uint256) external => DISPATCHER(true);
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
         f.selector != sig:erc20WrapperDepositFor(address, address, uint256).selector &&
         f.selector != sig:erc4626Mint(address, uint256, uint256,  address).selector &&
         f.selector != sig:erc4626Deposit(address, uint256, uint256, address).selector &&
         f.selector != sig:morphoSupply(GeneralAdapter1.MarketParams, uint256, uint256, uint256, address, bytes).selector &&
         f.selector != sig:morphoSupplyCollateral(GeneralAdapter1.MarketParams, uint256, address, bytes).selector &&
         f.selector != sig:morphoRepay(GeneralAdapter1.MarketParams, uint256, uint256, uint256, address, bytes).selector &&

         f.selector != sig:morphoWithdraw(GeneralAdapter1.MarketParams, uint256, uint256, uint256, address).selector &&
         f.selector != sig:morphoWithdrawCollateral(GeneralAdapter1.MarketParams, uint256, address).selector &&

         f.selector != sig:morphoFlashLoan(address, uint256, bytes).selector
}{
    // Set up inital state.
    require !approveCalled;
    f(e, args);
    assert !approveCalled;
}

// Check that the wrapper's allowance is set to zero for the adapter.
rule erc20WrapperDepositForAllowanceNull(env e, address wrapper, address receiver, uint256 amount) {
    erc20WrapperDepositFor(e, wrapper, receiver, amount);
    assert wrapper.underlying(e).allowance(e, currentContract, wrapper) == 0;
}

// Check that the vault's allowance is set to zero for the adapter.
rule erc4626MintAllowanceNull(env e, address vault, uint256 shares, uint256 maxSharePriceE27, address receiver) {
    erc4626Mint(e, vault, shares, maxSharePriceE27, receiver);
    assert vault.asset(e).allowance(e, currentContract, vault) == 0;
}

// Check that the vault's allowance is set to zero for the adapter.
rule erc462DepositAllowanceNull(env e, address vault, uint256 assets, uint256 maxSharePriceE27, address receiver) {
    erc4626Deposit(e, vault, assets, maxSharePriceE27, receiver);
    assert vault.asset(e).allowance(e, currentContract, vault) == 0;
}
