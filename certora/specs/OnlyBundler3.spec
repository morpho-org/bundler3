// SPDX-License-Identifier: GPL-2.0-or-later

using Morpho as Morpho;
using Bundler3 as Bundler3;

// Check that Morpho callbacks can be called only by Morpho.
rule morphoCallbacks(method f, env e, calldataarg data) filtered {
    f -> f.selector == sig:onMorphoSupply(uint256, bytes).selector ||
         f.selector == sig:onMorphoSupplyCollateral(uint256, bytes).selector ||
         f.selector == sig:onMorphoRepay(uint256, bytes).selector ||
         f.selector == sig:onMorphoFlashLoan(uint256, bytes).selector
}
{
    f@withrevert(e,data);
    assert Morpho != e.msg.sender => lastReverted;
}


// Check that adapters' methods, except those filtered out, can be called only by the Bundler3.
rule onlyBundler3(method f, env e, calldataarg data) filtered {
    // Do not check view functions or the `receive` function, which is safe as it is empty.
    f -> !f.isView && !f.isFallback &&
         f.selector != sig:onMorphoSupply(uint256, bytes).selector &&
         f.selector != sig:onMorphoSupplyCollateral(uint256, bytes).selector &&
         f.selector != sig:onMorphoRepay(uint256, bytes).selector &&
         f.selector != sig:onMorphoFlashLoan(uint256, bytes).selector
}
{
    f@withrevert(e,data);
    assert Bundler3 != e.msg.sender => lastReverted;
}
