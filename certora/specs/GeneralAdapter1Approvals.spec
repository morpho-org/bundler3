// SPDX-License-Identifier: GPL-2.0-or-later

methods{
    function _.depositFor(address, uint256) external => DISPATCHER(true);
    function _.underlying() external => DISPATCHER(true);
    function _.mint(uint256, address) external  => DISPATCHER(true);
    function _.deposit(uint256, address) external => DISPATCHER(true);
    function _.asset() external => DISPATCHER(true);
    function _.approve(address, uint256) external => DISPATCHER(true);
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