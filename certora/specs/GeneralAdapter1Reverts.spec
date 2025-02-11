// SPDX-License-Identifier: GPL-2.0-or-later

using WETH9 as WETH;
using Morpho as Morpho;
using ERC20Mock as ERC20Mock;
using ERC20USDT as ERC20USDT;
using ERC20NoRevert as ERC20NoRevert;
using Bundler3 as Bundler3;
using Permit2 as Permit2;

methods {
    function _.mint(uint256, address) external  => DISPATCHER(true);
    function _.deposit(uint256, address) external => DISPATCHER(true);
    function _.withdraw(uint256, address, address) external => DISPATCHER(true);
    function _.redeem(uint256, address, address) external => DISPATCHER(true);
    function _.approve(address, uint256)  external => DISPATCHER(true);
    function _.balanceOf(address) external => DISPATCHER(true);
    function _.transfer(address, uint256) external => DISPATCHER(true);
    function _.transferFrom(address, address, uint256) external => DISPATCHER(true);
    function Permit2.allowance(address, address, address) external returns (uint160, uint48, uint48) envfree;
    function Bundler3.initiator() external returns address envfree;
}

// Check that the state didn't change upon a native transfer with 0 ETH using the adapter.
rule nativeTransferChange(env e, address receiver, uint256 amount) {
    storage storageBefore = lastStorage;
    uint256 senderBalanceBefore = nativeBalances[currentContract];

    nativeTransfer(e, receiver, amount);

    // Equivalence is rewritten to avoid issue with quantifiers and polarity.
    bool noChangeExpectedCondition = amount == max_uint256 && senderBalanceBefore == 0;
    assert (noChangeExpectedCondition => storageBefore == lastStorage) && (storageBefore == lastStorage => noChangeExpectedCondition);
}

// Check that the state didn't change upon unwrapping 0 ETH using the adapter.
rule erc20TransferChange(env e, address token, address receiver, uint256 amount) {
    uint256 senderBalanceBefore = token.balanceOf(e, currentContract);
    storage storageBefore = lastStorage;

    erc20Transfer(e, token, receiver, amount);

    // Equivalence is rewritten to avoid issue with quantifiers and polarity.
    bool noChangeExpectedCondition = amount == 0 || (senderBalanceBefore == 0 && amount == max_uint256);
    assert (noChangeExpectedCondition => storageBefore == lastStorage) && (storageBefore == lastStorage => noChangeExpectedCondition);
}

// Check that state didn't change upon an ERC20 self-transfer using the adapter.
rule erc20TransferFromChange(env e, address token, address receiver, uint256 amount) {

    // Safe require as the initiator can't be the adatper.
    require Bundler3.initiator() != currentContract;

    uint256 senderBalanceBefore = token.balanceOf(e, currentContract);
    storage storageBefore = lastStorage;

    erc20TransferFrom(e, token, receiver, amount);

    // Equivalence is rewritten to avoid issue with quantifiers and polarity.
    bool noChangeExpectedCondition = receiver == Bundler3.initiator() && token.allowance(e, Bundler3.initiator(), currentContract) == max_uint256 ;
    assert (noChangeExpectedCondition => storageBefore == lastStorage) && (storageBefore == lastStorage => noChangeExpectedCondition);
}

// Check that state didn't change upon an ERC20 self-transfer through Permit2 using the adapter.
rule permit2TransferFromChange(env e, address token, address receiver, uint256 amount) {

    // Safe require as the initiator can't be the adatper.
    require Bundler3.initiator() != currentContract;
    // Safe require as the initiator can't be Permit2.
    require Bundler3.initiator() != Permit2;

    storage storageBefore = lastStorage;
    uint160 adapterAllowance;
    uint256 senderBalanceBefore = token.balanceOf(e, Bundler3.initiator());
    (adapterAllowance, _, _)= Permit2.allowance(receiver, token, currentContract);

    permit2TransferFrom(e, token, receiver, amount);

    uint256 permit2Allowance = token.allowance(e, Bundler3.initiator(), Permit2);

    // Equivalence is rewritten to avoid issue with quantifiers and polarity.
    bool noChangeExpectedCondition = amount == 0 || (amount == max_uint256 && senderBalanceBefore == 0) || (receiver == Bundler3.initiator() && adapterAllowance == max_uint160 && permit2Allowance == max_uint256);
    assert (noChangeExpectedCondition => storageBefore == lastStorage) && (storageBefore == lastStorage => noChangeExpectedCondition);
}

// Check that balances and state didn't change upon unwrapping 0 ETH using the adapter.
rule unwrapNativeChange(env e, uint256 amount, address receiver) {
    uint256 holderBalanceBefore = WETH.balanceOf(e, currentContract);
    storage storageBefore = lastStorage;

    unwrapNative(e, amount, receiver);

    // Equivalence is rewritten to avoid issue with quantifiers and polarity.
    bool noChangeExpectedCondition = amount == 0 || (amount == max_uint256 && holderBalanceBefore == 0) || receiver == WETH;
    assert (noChangeExpectedCondition => storageBefore == lastStorage) && (storageBefore == lastStorage => noChangeExpectedCondition);
}

// Check that if the function call doesn't revert the state changes.
rule revertOrStateChanged(env e, method f, calldataarg args) filtered {
    f -> !f.isView && !f.isFallback &&
         // We don't check the property for Morpho callbacks.
         f.selector != sig:onMorphoSupply(uint256, bytes).selector &&
         f.selector != sig:onMorphoSupplyCollateral(uint256, bytes).selector &&
         f.selector != sig:onMorphoRepay(uint256, bytes).selector &&
         f.selector != sig:onMorphoFlashLoan(uint256, bytes).selector &&
         // Property doesn't hold for nativeTransfer, see rule nativeTransferChange.
         f.selector != sig:nativeTransfer(address, uint256).selector &&
         // Property doesn't hold for erc20Transfer, see rule erc20TransferChange.
         f.selector != sig:erc20Transfer(address, address, uint256).selector &&
         // Property doesn't hold for erc20TransferFrom, see rule erc20TransferFromChange.
         f.selector != sig:erc20TransferFrom(address, address, uint256).selector &&
         // Property doesn't hold for permit2TransferFrom, see rule permit2TransferFromChange.
         f.selector != sig:permit2TransferFrom(address, address, uint256).selector &&
         // Property doesn't hold for unwrapNative, see rule unwrapNativeChange.
         f.selector != sig:unwrapNative(uint256, address).selector &&
         // Property doesn't hold for morphoFlashLoan.
         f.selector != sig:morphoFlashLoan(address, uint256, bytes).selector
}{
    // Safe require as the initiator can't be zero when executing a bundle.
    require Bundler3.initiator() != 0;
    // Safe require as the initiator can't be the adapter.
    require Bundler3.initiator() != currentContract;

    storage storageBefore = lastStorage;

    f@withrevert(e, args);

    assert !lastReverted => storageBefore != lastStorage;
}
