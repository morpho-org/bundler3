// SPDX-License-Identifier: GPL-2.0-or-later

using GeneralAdapter1 as GeneralAdapter1;

// Check the equivalence on input's zero conditions between the adapter's morphoSupply and the Morpho.supply entrypoints.
rule morphoSupplyExactlyOneZero(
    env e,
    GeneralAdapter1.MarketParams marketParams,
    uint256 assets,
    uint256 shares,
    uint256 maxSharePriceE27,
    address onBehalf,
    bytes data
  ) {
    morphoSupply@withrevert(e, marketParams, assets, shares, maxSharePriceE27, onBehalf, data);
    assert !lastReverted => exactlyOneZero(assets, shares);
}

// Check the equivalence on input's zero conditions between the adapter's morphoSupplyCollateral and the Morpho.supplyCollateral entrypoints.
rule morphoSupplyCollateralAssetsNonZero(
    env e,
    GeneralAdapter1.MarketParams marketParams,
    uint256 assets,
    address onBehalf,
    bytes data
  ) {
    morphoSupplyCollateral@withrevert(e, marketParams, assets, onBehalf, data);
    assert !lastReverted => assets != 0;
}

// Check the equivalence on input's zero conditions between the adapter's morphoBorrow and the Morpho.borrow entrypoints.
rule morphoBorrowExactlyOneZero(
    env e,
    GeneralAdapter1.MarketParams marketParams,
    uint256 assets,
    uint256 shares,
    uint256 maxSharePriceE27,
    address receiver
  ) {
    morphoBorrow@withrevert(e, marketParams, assets, shares, maxSharePriceE27, receiver);
    assert !lastReverted => exactlyOneZero(assets, shares);
}

// Check the equivalence on input's zero conditions between the adapter's morphoRepay and the Morpho.repay entrypoints.
rule morphoRepayExactlyOneZero(
    env e,
    GeneralAdapter1.MarketParams marketParams,
    uint256 assets,
    uint256 shares,
    uint256 maxSharePriceE27,
    address onBehalf,
    bytes data
  ) {
    morphoRepay@withrevert(e, marketParams, assets, shares, maxSharePriceE27, onBehalf, data);
    assert !lastReverted => exactlyOneZero(assets, shares);
}

// Check the equivalence on input's zero conditions between the adapter's morphoWithdraw and the Moprho.withdraw entrypoints.
rule morphoWithdrawExactlyOneZero(
    env e,
    GeneralAdapter1.MarketParams marketParams,
    uint256 assets,
    uint256 shares,
    uint256 maxSharePriceE27,
    address receiver
  ) {
    morphoWithdraw@withrevert(e, marketParams, assets, shares, maxSharePriceE27, receiver);
    assert !lastReverted => exactlyOneZero(assets, shares);
}

// Check the equivalence on input's zero conditions between the adapter's morphoWithdrawCollateral and the Moprho.withdrawCollateral entrypoints.
rule morphoWithdrawCollateralAssetsNonZero(
    env e,
    GeneralAdapter1.MarketParams marketParams,
    uint256 assets,
    address receiver
  ) {
    morphoWithdrawCollateral@withrevert(e, marketParams, assets, receiver);
    assert !lastReverted => assets != 0;
}

// Check the equivalence on input's zero conditions between the adapter's morphoFlashLoan and the Moprho.flashLoan entrypoints.
rule morphoFlashLoanAssetsNonZero(env e, address token, uint256 assets, bytes data) {
    morphoFlashLoan@withrevert(e, token, assets, data);
    assert !lastReverted => assets != 0;
}
