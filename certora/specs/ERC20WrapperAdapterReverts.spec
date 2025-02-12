// SPDX-License-Identifier: GPL-2.0-or-later

using Bundler3 as Bundler3;

methods {
    function _.depositFor(address, uint256) external => DISPATCHER(true);
    function _.withdrawTo(address, uint256) external => DISPATCHER(true);
    function _.approve(address, uint256)  external => DISPATCHER(true);
    function _.balanceOf(address) external => DISPATCHER(true);
    function _.transfer(address, uint256) external => DISPATCHER(true);
    function _.transferFrom(address, address, uint256) external => DISPATCHER(true);
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

// Check that the state didn't change upon sending 0 tokens using the adapter.
rule erc20TransferChange(env e, address token, address receiver, uint256 amount) {
    uint256 senderBalanceBefore = token.balanceOf(e, currentContract);
    storage storageBefore = lastStorage;

    erc20Transfer(e, token, receiver, amount);

    // Equivalence is rewritten to avoid issue with quantifiers and polarity.
    bool noChangeExpectedCondition = amount == max_uint256 && senderBalanceBefore == 0;
    assert (noChangeExpectedCondition => storageBefore == lastStorage) && (storageBefore == lastStorage => noChangeExpectedCondition);
}

// Check that if the function call doesn't revert the state changes.
rule revertOrStateChanged(env e, method f, calldataarg args) filtered {
    f -> !f.isView && !f.isFallback &&
         // Property doesn't hold for nativeTransfer, see rule nativeTransferChange.
         f.selector != sig:nativeTransfer(address, uint256).selector &&
         // Property doesn't hold for erc20Transfer, see rule erc20TransferChange.
         f.selector != sig:erc20Transfer(address, address, uint256).selector
}{
    // Safe require as the initiator can't be zero when executing a bundle.
    require Bundler3.initiator() != 0;
    // Safe require as the initiator can't be the adapter.
    require Bundler3.initiator() != currentContract;

    storage storageBefore = lastStorage;

    f@withrevert(e, args);

    assert !lastReverted => storageBefore != lastStorage;
}
