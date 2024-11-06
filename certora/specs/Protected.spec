// SPDX-License-Identifier: GPL-2.0-or-later

// Check that all methods except those noted below comply with the `protected` modifier when an initiator has been set.
rule protectedWithSetInitiator(method f, env e, calldataarg data) filtered {
    // Do not check view functions.
    f -> !f.isView &&
    // Do not check the fallback function.
    !f.isFallback &&
    // Do not check multicall, which is used to start a new bundle.
    f.selector != sig:multicall(bytes[]).selector
}
{
    // Safe require because `protected` functions should be callable by the initiator.
    require e.msg.sender != currentContract._initiator;
    // Safe require because `protected` functions should be callable by Morpho.
    require e.msg.sender != currentContract.MORPHO;
    f@withrevert(e,data);
    assert lastReverted;
}
