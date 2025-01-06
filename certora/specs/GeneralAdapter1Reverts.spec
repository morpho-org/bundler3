// SPDX-License-Identifier: GPL-2.0-or-later

using WETH9 as WETH;
using Morpho as Morpho;
using ERC20Mock as ERC20;
using SafeERC20 as SafeERC20;
using ERC4626Mock as ERC4626;
using ERC20WrapperMock as ERC20Wrapper;
using GeneralAdapter1 as GeneralAdapter1;
using Bundler as Bundler;

methods {
    function _.balanceOf(address) external => DISPATCHER(true);
    function _.depositFor(address, uint256) external => DISPATCHER(true);
    function _.withdrawTo(address, uint256) external => DISPATCHER(true);
    function _.mint(uint256, address) external  => DISPATCHER(true);
    function _.deposit(uint256, address) external => DISPATCHER(true);
    function _.withdraw(uint256, address, address) external => DISPATCHER(true);
    function _.redeem(uint256, address, address) external => DISPATCHER(true);
    function _.approve(address, uint256)  external => DISPATCHER(true);
    function _.transfer(address, uint256) external => DISPATCHER(true);
    function _.transferFrom(address, address, uint256) external => DISPATCHER(true);
    function _.transferFrom(address, address, uint160, address) external => DISPATCHER(true);
    function Morpho.supply(Morpho.MarketParams, uint256, uint256, address, bytes) external;
    function Morpho.supplyCollateral(Morpho.MarketParams, uint256, address, bytes) external;
    function Morpho.borrow(Morpho.MarketParams, uint256, uint256, address, address) external;
    function Morpho.repay(Morpho.MarketParams, uint256, uint256, address, bytes) external;
    function Morpho.withdraw(Morpho.MarketParams, uint256, uint256, address, address) external;
    function Morpho.withdrawCollateral(Morpho.MarketParams, uint256, address, address) external;
    function WETH.balanceOf(address) external returns uint256 envfree;
    function WETH.deposit() external;
    function WETH.withdraw(uint256) external;
    function Bundler.initiator() external returns address envfree;
}

definition storageChanged (storage before, storage last) returns bool =
    before[Morpho] != last[Morpho] ||
    before[ERC4626] != last[ERC4626] ||
    before[ERC20Wrapper] != last[ERC20Wrapper] &&
    !(before[Morpho] != last[Morpho] &&
    before[ERC4626] != last[ERC4626] &&
    before[ERC20Wrapper] != last[ERC20Wrapper]);

rule nativeTransferChange(env e, address receiver, uint256 amount) {
    //require amount != max_uint256;
    uint256 adapterBalanceBefore = nativeBalances[currentContract];
    uint256 receiverBalanceBefore = nativeBalances[receiver];
    nativeTransfer@withrevert(e, receiver, amount);
    assert !lastReverted && amount != 0 => adapterBalanceBefore == nativeBalances[currentContract] + amount && receiverBalanceBefore + amount == nativeBalances[receiver];
    assert lastReverted || amount == 0 => adapterBalanceBefore == nativeBalances[currentContract] && receiverBalanceBefore == nativeBalances[receiver];
}

rule erc20TransferRevert(env e, address token, address receiver, uint256 amount) {
    storage storageBefore = lastStorage;
    erc20Transfer@withrevert(e, token, receiver, amount);
    assert !lastReverted && amount != 0 && token == ERC20 && token.balanceOf(e, currentContract) != 0 => storageBefore[ERC20] != lastStorage[ERC20];
    assert  token == ERC20 && lastReverted || amount == 0 => storageBefore[ERC20] == lastStorage[ERC20];
}

rule erc20WrapperDepositForRevert(env e, address wrapper, address receiver, uint256 amount) {
    storage storageBefore = lastStorage;
    erc20WrapperDepositFor@withrevert(e, wrapper, receiver, amount);
    assert !lastReverted => wrapper == ERC20Wrapper && storageBefore[ERC20Wrapper] != lastStorage[ERC20Wrapper];
    assert lastReverted && wrapper == ERC20Wrapper => storageBefore[ERC20Wrapper] == lastStorage[ERC20Wrapper];
}

rule erc20WrapperWithdrawToRevert(env e, address wrapper, address receiver, uint256 amount) {
    storage storageBefore = lastStorage;
    erc20WrapperWithdrawTo@withrevert(e, wrapper, receiver, amount);
    assert !lastReverted => wrapper == ERC20Wrapper && storageBefore[ERC20Wrapper] != lastStorage[ERC20Wrapper];
    assert lastReverted && wrapper == ERC20Wrapper => storageBefore[ERC20Wrapper] == lastStorage[ERC20Wrapper];
}

rule erc4626MintRevert(env e, address vault, uint256 shares, uint256 maxSharePriceE27, address receiver){
    storage storageBefore = lastStorage;
    erc4626Mint@withrevert(e, vault, shares, maxSharePriceE27, receiver);
    assert !lastReverted => vault == ERC4626 && storageBefore[ERC4626] != lastStorage[ERC4626];
    assert lastReverted && vault == ERC4626 => storageBefore[ERC4626] == lastStorage[ERC4626];
}

rule wrapNativeChange(env e, uint256 amount, address receiver) {
    //require amount != max_uint256;
    uint256 adapterNativeBalanceBefore = nativeBalances[currentContract];
    uint256 receiverWrappedBalanceBefore = WETH.balanceOf(receiver);
    require receiverWrappedBalanceBefore + amount <= max_uint256;
    wrapNative@withrevert(e, amount, receiver);
    bool reverted = lastReverted;
    assert !reverted => receiverWrappedBalanceBefore + amount == WETH.balanceOf(receiver) && adapterNativeBalanceBefore == nativeBalances[currentContract] + amount;
    assert reverted => receiverWrappedBalanceBefore == WETH.balanceOf(receiver) && adapterNativeBalanceBefore == nativeBalances[currentContract];
}

rule unwrapNativeChange(env e, uint256 amount, address receiver) {
    //require amount != max_uint256;
    uint256 receiverNativeBalanceBefore = nativeBalances[receiver];
    uint256 adapterWrappedBalanceBefore = WETH.balanceOf(currentContract);
    unwrapNative@withrevert(e, amount, receiver);
    bool reverted = lastReverted;
    assert !reverted && receiver != WETH => adapterWrappedBalanceBefore == WETH.balanceOf(currentContract) + amount && (receiverNativeBalanceBefore + amount == nativeBalances[receiver]);
    assert reverted || receiver == WETH => adapterWrappedBalanceBefore == WETH.balanceOf(currentContract) && (receiverNativeBalanceBefore == nativeBalances[receiver]);
}

rule revertOrStateChanged(env e, method f, calldataarg args) filtered {
    f -> !f.isView && !f.isFallback &&
         f.selector != sig:onMorphoSupply(uint256, bytes).selector &&
         f.selector != sig:onMorphoSupplyCollateral(uint256, bytes).selector &&
         f.selector != sig:onMorphoRepay(uint256, bytes).selector &&
         f.selector != sig:onMorphoFlashLoan(uint256, bytes).selector &&
         f.selector != sig:morphoFlashLoan(address, uint256, bytes).selector &&
         f.selector != sig:nativeTransfer(address, uint256).selector &&
         f.selector != sig:wrapNative(uint256, address).selector &&
         f.selector != sig:unwrapNative(uint256, address).selector &&
         f.selector != sig:erc20Transfer(address, address, uint256).selector &&
         f.selector != sig:erc20TransferFrom(address, address, uint256).selector
}{
    require Bundler.initiator() != 0;
    storage storageBefore = lastStorage;
    f@withrevert(e, args);
    assert !lastReverted => storageChanged(storageBefore, lastStorage);
    assert lastReverted => !storageChanged(storageBefore, lastStorage);
}
