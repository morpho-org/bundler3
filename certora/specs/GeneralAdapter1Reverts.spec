// SPDX-License-Identifier: GPL-2.0-or-later

using WETH9 as WETH;
using Morpho as Morpho;
using ERC4626Mock as ERC4626;
using ERC20Mock as ERC20Mock;
using ERC20USDT as ERC20USDT;
using ERC20NoRevert as ERC20NoRevert;
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

// Wether or not storage of interest has changed.
definition storageChanged (storage before, storage last) returns bool =
    (before[Morpho] != last[Morpho] ||
    before[ERC4626] != last[ERC4626] ||
    before[ERC20Wrapper] != last[ERC20Wrapper] ||
    before[WETH] != last[WETH] || before[ERC20Mock] != last[ERC20Mock] ||
     before[ERC20NoRevert] != last[ERC20NoRevert] || before[ERC20USDT] != last[ERC20USDT]);

// Check that balances changed upon native tansfers with the adapter.
rule nativeTransferChange(env e, address receiver, uint256 amount) {
    uint256 adapterBalanceBefore = nativeBalances[currentContract];
    uint256 receiverBalanceBefore = nativeBalances[receiver];

    nativeTransfer@withrevert(e, receiver, amount);

    // Check case when specifying a given amount.
    assert !lastReverted && amount != max_uint256 => adapterBalanceBefore == nativeBalances[currentContract] + amount && receiverBalanceBefore + amount == nativeBalances[receiver];

    // Check case when transferring the whole balance.
    assert !lastReverted && amount == max_uint256 => adapterBalanceBefore + receiverBalanceBefore == nativeBalances[receiver]  && nativeBalances[currentContract] == 0;

    // Check that state doesnt change when using amount equals zero.
    assert amount == 0 => adapterBalanceBefore == nativeBalances[currentContract] && receiverBalanceBefore == nativeBalances[receiver];
}

// Check that balances changed upon ERC20 tansfers with the adapter.
rule erc20TransferRevert(env e, address token, address receiver, uint256 amount) {
    storage storageBefore = lastStorage;
    uint256 balanceSenderBefore = token.balanceOf(e, currentContract);
    erc20Transfer@withrevert(e, token, receiver, amount);

    // Check case using a standard OpenZeppelin ERC20 implementation.
    assert !lastReverted && amount != 0 && token == ERC20Mock && balanceSenderBefore != 0 => storageBefore[ERC20Mock] != lastStorage[ERC20Mock];
    // Check that state doesnt change when using amount equals zero.
    assert  token == ERC20Mock && amount == 0 => storageBefore[ERC20Mock] == lastStorage[ERC20Mock];

    // Check case using a token implementation that doesn't revert.
    assert !lastReverted && amount != 0 && token == ERC20NoRevert && balanceSenderBefore != 0 => storageBefore[ERC20NoRevert] != lastStorage[ERC20NoRevert];
    // Check that state doesnt change when using amount equals zero.
    assert  token == ERC20NoRevert && amount == 0 => storageBefore[ERC20NoRevert] == lastStorage[ERC20NoRevert];

    // Check case using a USDT's token implementation.
    assert !lastReverted && amount != 0 && token == ERC20USDT && balanceSenderBefore != 0 => storageBefore[ERC20USDT] != lastStorage[ERC20USDT];
    // Check that state doesnt change when using amount equals zero.
    assert  token == ERC20USDT && amount == 0 => storageBefore[ERC20USDT] == lastStorage[ERC20USDT];
}

// Check that balances changed upon ERC20 tansfers from the initiator with the adapter.
rule erc20TransferFromRevert(env e, address token, address receiver, uint256 amount) {

    // Safe require as the initiator can't be the adatper.
    require Bundler.initiator() != currentContract;

    storage storageBefore = lastStorage;
    uint256 balanceSenderBefore = token.balanceOf(e, Bundler.initiator());

    erc20TransferFrom@withrevert(e, token, receiver, amount);

    // Check case using a standard OpenZeppelin ERC20 implementation.
    assert !lastReverted && amount != 0 && token == ERC20Mock && balanceSenderBefore != 0 => storageBefore[ERC20Mock] != lastStorage[ERC20Mock];
    assert  token == ERC20Mock && lastReverted || amount == 0 => storageBefore[ERC20Mock] == lastStorage[ERC20Mock];

    // Check case using a token implementation that doesn't revert.
    assert !lastReverted && amount != 0 && token == ERC20NoRevert && balanceSenderBefore != 0 => storageBefore[ERC20NoRevert] != lastStorage[ERC20NoRevert];
    assert  token == ERC20NoRevert && lastReverted || amount == 0 => storageBefore[ERC20NoRevert] == lastStorage[ERC20NoRevert];

    // Check case using a USDT's token implementation.
    assert !lastReverted && amount != 0 && token == ERC20USDT && balanceSenderBefore != 0 => storageBefore[ERC20USDT] != lastStorage[ERC20USDT];
    // Check that state doesnt change when using amount equals zero.
    assert  amount == 0 => storageBefore[ERC20USDT] == lastStorage[ERC20USDT];
}

// Check that balances changed upon ERC20 tansfers with the adapter.
rule erc20WrapperDepositForRevert(env e, address wrapper, address receiver, uint256 amount) {
    storage storageBefore = lastStorage;

    erc20WrapperDepositFor@withrevert(e, wrapper, receiver, amount);

    assert !lastReverted => wrapper == ERC20Wrapper && storageBefore[ERC20Wrapper] != lastStorage[ERC20Wrapper];
}

// Check that ERC20Wrapper state changed upon ERC20Wrapper withdrawals using the adapter.
rule erc20WrapperWithdrawToRevert(env e, address wrapper, address receiver, uint256 amount) {
    storage storageBefore = lastStorage;

    erc20WrapperWithdrawTo@withrevert(e, wrapper, receiver, amount);

    assert !lastReverted => wrapper == ERC20Wrapper && storageBefore[ERC20Wrapper] != lastStorage[ERC20Wrapper];
}

// Check that balances and state changed upon wrapping ETH using the adapter.
rule wrapNativeChange(env e, uint256 amount, address receiver) {
    uint256 adapterNativeBalanceBefore = nativeBalances[currentContract];
    uint256 receiverWrappedBalanceBefore = WETH.balanceOf(receiver);

    // Safe require as this is not possible.
    require receiverWrappedBalanceBefore + adapterNativeBalanceBefore <= max_uint256;

    wrapNative@withrevert(e, amount, receiver);
    bool reverted = lastReverted;

    // Check case when specifying a given amount.
    assert !reverted && amount != max_uint256 => receiverWrappedBalanceBefore + amount == WETH.balanceOf(receiver) && adapterNativeBalanceBefore == nativeBalances[currentContract] + amount;

    // Check case when transferring the whole balance.
    assert !reverted && amount == max_uint256 => receiverWrappedBalanceBefore + adapterNativeBalanceBefore == WETH.balanceOf(receiver) && nativeBalances[currentContract] == 0;

    // Check that state doesnt change when using amount equals zero.
    assert amount == 0 => receiverWrappedBalanceBefore == WETH.balanceOf(receiver) && adapterNativeBalanceBefore == nativeBalances[currentContract];
}

// Check that balances and state changed upon unwrapping ETH using the adapter.
rule unwrapNativeChange(env e, uint256 amount, address receiver) {
    uint256 receiverNativeBalanceBefore = nativeBalances[receiver];
    uint256 adapterWrappedBalanceBefore = WETH.balanceOf(currentContract);

    unwrapNative@withrevert(e, amount, receiver);
    bool reverted = lastReverted;

    // Check case when specifying a given amount.
    assert !reverted && receiver != WETH && amount != max_uint256 => adapterWrappedBalanceBefore == WETH.balanceOf(currentContract) + amount && receiverNativeBalanceBefore + amount == nativeBalances[receiver];

    // Check case when transferring the whole balance.
    assert !reverted && receiver != WETH && amount == max_uint256 => adapterWrappedBalanceBefore + receiverNativeBalanceBefore == nativeBalances[receiver] && WETH.balanceOf(currentContract) == 0;

    // Check that state doesnt change when using amount equals zero or if the receiver is the WETH contract.
    assert receiver == WETH || amount == 0 => adapterWrappedBalanceBefore == WETH.balanceOf(currentContract) && (receiverNativeBalanceBefore == nativeBalances[receiver]);
}


// Check that if the function call doesn't revert the state changes.
rule revertOrStateChanged(env e, method f, calldataarg args) filtered {
    f -> !f.isView && !f.isFallback &&
         f.selector != sig:onMorphoSupply(uint256, bytes).selector &&
         f.selector != sig:onMorphoSupplyCollateral(uint256, bytes).selector &&
         f.selector != sig:onMorphoRepay(uint256, bytes).selector &&
         f.selector != sig:onMorphoFlashLoan(uint256, bytes).selector &&
         // Property checked in a different way.
         f.selector != sig:nativeTransfer(address, uint256).selector &&
         f.selector != sig:wrapNative(uint256, address).selector &&
         f.selector != sig:unwrapNative(uint256, address).selector &&
         f.selector != sig:erc20Transfer(address, address, uint256).selector &&
         f.selector != sig:erc20TransferFrom(address, address, uint256).selector &&
        // Property doesn't hold for the following.
         f.selector != sig:morphoFlashLoan(address, uint256, bytes).selector &&
         f.selector != sig:permit2TransferFrom(address, address, uint256).selector
}{
    // Safe require as the initiator can't be zero when executing a bundle.
    require Bundler.initiator() != 0;

    storage storageBefore = lastStorage;

    f@withrevert(e, args);

    assert !lastReverted => storageChanged(storageBefore, lastStorage);
}
