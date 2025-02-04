// SPDX-License-Identifier: GPL-2.0-or-later

import "AllowancesInvariant.spec";

methods{
    function _.repay(address, uint256, uint256, address) external => HAVOC_ECF;
    function _.approve(address, uint256) external => DISPATCHER(true);
}

use invariant allowancesNotChanged filtered {
    // Do not check view functions or the `receive` function, which is safe as it is empty.
    f -> !f.isView && !f.isFallback &&
         f.selector != sig:aaveV2Repay(address, uint256, uint256, address).selector
}

// Check that the pools's allowance is set to zero for the adapter.
rule aaveV2RepayAllowanceNull(env e, address token, uint256 amount, uint256 interestRateMode, address onBehalf) {
    aaveV2Repay(e, token, amount, interestRateMode, onBehalf);
    assert token.allowance(e, currentContract, currentContract.AAVE_V2_POOL) == 0;
}
