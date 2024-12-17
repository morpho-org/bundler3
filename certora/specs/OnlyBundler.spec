// SPDX-License-Identifier: GPL-2.0-or-later

// Check that Morpho callbacks can be called only by MORPHO.
rule morphoCallbacks(method f, env e, calldataarg data) filtered {
    // Do not check view functions.
    f -> !f.isView && !f.isFallback &&
         f.selector == sig:onMorphoSupply(uint256, bytes).selector ||
         f.selector == sig:onMorphoSupplyCollateral(uint256, bytes).selector ||
         f.selector == sig:onMorphoRepay(uint256, bytes).selector ||
         f.selector == sig:onMorphoFlashLoan(uint256, bytes).selector
}
{
    f@withrevert(e,data);
    assert currentContract.MORPHO != e.msg.sender => lastReverted;
}


// Check that adapters' methods, except those filtered out, can be called only by the BUNDLER.
rule onlyBundler(method f, env e, calldataarg data) filtered {
    // Do not check view functions.
    f -> !f.isView && !f.isFallback &&
         f.selector != sig:onMorphoSupply(uint256, bytes).selector &&
         f.selector != sig:onMorphoSupplyCollateral(uint256, bytes).selector &&
         f.selector != sig:onMorphoRepay(uint256, bytes).selector &&
         f.selector != sig:onMorphoFlashLoan(uint256, bytes).selector
}
{
    f@withrevert(e,data);
    assert currentContract.BUNDLER != e.msg.sender => lastReverted;
}
