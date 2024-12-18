// SPDX-License-Identifier: GPL-2.0-or-later

using GeneralAdapter1 as GeneralAdapter1;
using Morpho as Morpho;

methods {
    function Morpho.supply(GeneralAdapter1.MarketParams, uint256 assets, uint256 shares, address, bytes) external returns (uint256, uint256) => summaryCheckExactlyOneZero(assets, shares) ;
    function Morpho.supplyCollateral(GeneralAdapter1.MarketParams, uint256 assets, address, bytes) external => summaryCheckAssetsNonZero(assets) ;
    function Morpho.borrow(GeneralAdapter1.MarketParams, uint256 assets, uint256 shares, address, address) external returns (uint256, uint256) => summaryCheckExactlyOneZero(assets, shares) ;
    function Morpho.repay(GeneralAdapter1.MarketParams, uint256 assets, uint256 shares, address, bytes) external returns (uint256, uint256) => summaryCheckExactlyOneZero(assets, shares) ;
    function Morpho.withdraw(GeneralAdapter1.MarketParams, uint256 assets, uint256 shares, address, address) external returns (uint256, uint256) => summaryCheckExactlyOneZero(assets, shares) ;
    function Morpho.withdrawCollateral(GeneralAdapter1.MarketParams, uint256 assets, address, address) external => summaryCheckAssetsNonZero(assets) ;
    function Morpho.flashLoan(address, uint256 assets, bytes) external => summaryCheckAssetsNonZero(assets) ;
}

definition exactlyOneZero(uint256 assets, uint256 shares) returns bool = (assets == 0 && shares != 0) || (assets != 0 && shares == 0);

function summaryCheckAssetsNonZero (uint256 assets) {
    zeroConditionHolds = assets != 0;
}

function summaryCheckExactlyOneZero(uint256 assets, uint256 shares) returns (uint256, uint256) {
    zeroConditionHolds = exactlyOneZero(assets, shares);
    return (_,_);
}

// True when the values of assets or shares are consistent between Morpho and the adapter.
ghost bool zeroConditionHolds {
    init_state axiom zeroConditionHolds == false;
}

// Check that calls with safe values for `assets` or `shares` are consistent.
rule morphoSupplyExactlyOneZero(
    env e,
    GeneralAdapter1.MarketParams marketParams,
    uint256 assets,
    uint256 shares,
    uint256 maxSharePriceE27,
    address onBehalf,
    bytes data
  ) {
    morphoSupply(e, marketParams, assets, shares, maxSharePriceE27, onBehalf, data);
    assert zeroConditionHolds <=> exactlyOneZero(assets, shares);
}

// Check that calls with safe values for `assets` are consistent.
rule morphoSupplyCollateralAssetsNonZero(
    env e,
    GeneralAdapter1.MarketParams marketParams,
    uint256 assets,
    address onBehalf,
    bytes data
  ) {
    morphoSupplyCollateral(e, marketParams, assets, onBehalf, data);
    assert zeroConditionHolds <=> assets != 0;
}

// Check that calls with safe values for `assets` or `shares` are consistent.
rule morphoBorrowExactlyOneZero(
    env e,
    GeneralAdapter1.MarketParams marketParams,
    uint256 assets,
    uint256 shares,
    uint256 maxSharePriceE27,
    address receiver
  ) {
    morphoBorrow(e, marketParams, assets, shares, maxSharePriceE27, receiver);
    assert zeroConditionHolds <=> exactlyOneZero(assets, shares);
}

// Check that calls with safe values for `assets` or `shares` are consistent.
rule morphoRepayExactlyOneZero(
    env e,
    GeneralAdapter1.MarketParams marketParams,
    uint256 assets,
    uint256 shares,
    uint256 maxSharePriceE27,
    address onBehalf,
    bytes data
  ) {
    morphoRepay(e, marketParams, assets, shares, maxSharePriceE27, onBehalf, data);
    assert zeroConditionHolds <=> exactlyOneZero(assets, shares);
}

// Check that calls with safe values for `assets` or `shares` are consistent.
rule morphoWithdrawExactlyOneZero(
    env e,
    GeneralAdapter1.MarketParams marketParams,
    uint256 assets,
    uint256 shares,
    uint256 maxSharePriceE27,
    address receiver
  ) {
    morphoWithdraw(e, marketParams, assets, shares, maxSharePriceE27, receiver);
    assert zeroConditionHolds <=> exactlyOneZero(assets, shares);
}

// Check that calls with safe values for `assets` are consistent.
rule morphoWithdrawCollateralAssetsNonZero(
    env e,
    GeneralAdapter1.MarketParams marketParams,
    uint256 assets,
    address receiver
  ) {
    morphoWithdrawCollateral(e, marketParams, assets, receiver);
    assert zeroConditionHolds <=> assets != 0;
}

// Check that calls with safe values for `assets` are consistent.
rule morphoFlashLoanAssetsNonZero(env e, address token, uint256 assets, bytes data) {
    morphoFlashLoan(e, token, assets, data);
    assert zeroConditionHolds <=> assets != 0;
}
