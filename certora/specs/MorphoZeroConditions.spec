// SPDX-License-Identifier: GPL-2.0-or-later

using GeneralAdapter1 as GeneralAdapter1;

definition exactlyOneZero(uint256 assets, uint256 shares) returns bool = (assets == 0 && shares != 0) || (assets != 0 && shares == 0);

// Check that if morphoSupply call didn't revert, then Morpho's conditions on input are verified.
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
    assert !exactlyOneZero(assets, shares) => lastReverted;
}

// Check that if morphoSupplyCollateral call didn't revert, then Morpho's conditions on input are verified.
rule morphoSupplyCollateralAssetsNonZero(
    env e,
    GeneralAdapter1.MarketParams marketParams,
    uint256 assets,
    address onBehalf,
    bytes data
  ) {
    morphoSupplyCollateral@withrevert(e, marketParams, assets, onBehalf, data);
    assert assets == 0 => lastReverted;
}

// Check that if morphoBorrow call didn't revert, then Morpho's conditions on input are verified.
rule morphoBorrowExactlyOneZero(
    env e,
    GeneralAdapter1.MarketParams marketParams,
    uint256 assets,
    uint256 shares,
    uint256 maxSharePriceE27,
    address receiver
  ) {
    morphoBorrow@withrevert(e, marketParams, assets, shares, maxSharePriceE27, receiver);
    assert !exactlyOneZero(assets, shares) => lastReverted;
}

// Check that if morphoRepay call didn't revert, then Morpho's conditions on input are verified.
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
    assert !exactlyOneZero(assets, shares) => lastReverted;
}

// Check that if morphoWithdraw call didn't revert, then Morpho's conditions on input are verified.
rule morphoWithdrawExactlyOneZero(
    env e,
    GeneralAdapter1.MarketParams marketParams,
    uint256 assets,
    uint256 shares,
    uint256 maxSharePriceE27,
    address receiver
  ) {
    morphoWithdraw@withrevert(e, marketParams, assets, shares, maxSharePriceE27, receiver);
    assert !exactlyOneZero(assets, shares) => lastReverted;
}

// Check that if morphoWithdrawCollateral call didn't revert, then Morpho's conditions on input are verified.
rule morphoWithdrawCollateralAssetsNonZero(
    env e,
    GeneralAdapter1.MarketParams marketParams,
    uint256 assets,
    address receiver
  ) {
    morphoWithdrawCollateral@withrevert(e, marketParams, assets, receiver);
    assert assets == 0 => lastReverted;
}

// Check that if morphoFlashLoan call didn't revert, then Morpho's conditions on input are verified.
rule morphoFlashLoanAssetsNonZero(env e, address token, uint256 assets, bytes data) {
    morphoFlashLoan@withrevert(e, token, assets, data);
    assert assets == 0 => lastReverted;
}
