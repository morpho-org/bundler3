// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";

import "./helpers/LocalTest.sol";
import {IAugustusRegistry} from "../src/interfaces/IAugustusRegistry.sol";
import {MathLib} from "../lib/morpho-blue/src/libraries/MathLib.sol";
import {EventsLib} from "../src/libraries/EventsLib.sol";

contract ParaswapMorphoBundlesLocalTest is LocalTest {
    using MarketParamsLib for MarketParams;
    using MorphoBalancesLib for IMorpho;
    using MorphoLib for IMorpho;

    ERC20Mock collateralToken2;
    MarketParams internal marketParamsCollateral2;
    Id internal idCollateral2;

    ERC20Mock loanToken2;
    MarketParams internal marketParamsLoan2;
    Id internal idLoan2;

    // If ratio too close to 100%:
    // - debt accruals between bundle creation and tx may trigger a revert
    // - asset.toShares may overestimate share amount and trigger a revert
    //
    // If ratio too close to 0:
    // - final amount may be 0
    uint256 internal MIN_RATIO = WAD / 100;
    uint256 internal MAX_RATIO = 99 * WAD / 100;

    function setUp() public virtual override {
        super.setUp();
        augustus = new AugustusMock();
        augustusRegistryMock.setValid(address(augustus), true);

        // New loan token

        loanToken2 = new ERC20Mock("loan2", "B2");
        vm.label(address(loanToken2), "loanToken2");
        marketParamsLoan2 =
            MarketParams(address(loanToken2), address(collateralToken), address(oracle), address(irm), LLTV);
        idLoan2 = marketParamsLoan2.id();

        vm.prank(OWNER);
        morpho.createMarket(marketParamsLoan2);

        vm.startPrank(SUPPLIER);
        loanToken2.approve(address(morpho), type(uint256).max);
        loanToken.approve(address(morpho), type(uint256).max);

        vm.startPrank(USER);
        morpho.setAuthorization(address(genericModule1), true);
        collateralToken.approve(address(morpho), type(uint256).max);
        loanToken.approve(address(morpho), type(uint256).max);
        vm.stopPrank();

        // New collateral token

        collateralToken2 = new ERC20Mock("collateral2", "C2");
        vm.label(address(collateralToken2), "collateralToken2");
        marketParamsCollateral2 =
            MarketParams(address(loanToken), address(collateralToken2), address(oracle), address(irm), LLTV);
        idCollateral2 = marketParamsCollateral2.id();

        vm.prank(OWNER);
        morpho.createMarket(marketParamsCollateral2);
    }

    function _buyMorphoDebt(
        address srcToken,
        uint256 maxSrcAmount,
        uint256 destAmount,
        MarketParams memory marketParams,
        address receiver
    ) internal view returns (Call memory) {
        uint256 fromAmountOffset = 4 + 32 + 32;
        uint256 toAmountOffset = fromAmountOffset + 32;
        return _call(
            genericModule1,
            abi.encodeCall(
                genericModule1.paraswapBuyMorphoDebt,
                (
                    address(paraswapModule),
                    address(augustus),
                    abi.encodeCall(augustus.mockBuy, (srcToken, marketParams.loanToken, maxSrcAmount, destAmount)),
                    srcToken,
                    marketParams,
                    Offsets({exactAmount: toAmountOffset, limitAmount: fromAmountOffset, quotedAmount: 0}),
                    receiver
                )
            )
        );
    }

    /* WITHDRAW COLLATERAL AND SWAP */

    function testWithdrawCollateralAndSwap(uint256 collateralAmount, uint256 ratio) public {
        collateralAmount = bound(collateralAmount, MIN_AMOUNT, MAX_AMOUNT);

        _supplyCollateral(marketParams, collateralAmount, USER);

        ratio = bound(ratio, MIN_RATIO, WAD);
        uint256 srcAmount = collateralAmount * ratio / WAD;
        _createWithdrawCollateralAndSwapBundle(marketParams, address(collateralToken2), srcAmount, USER);

        skip(2 days);

        vm.prank(USER);
        bundler.multicall(bundle);

        assertEq(morpho.collateral(marketParams.id(), USER), collateralAmount - srcAmount, "sold");
        assertEq(collateralToken2.balanceOf(USER), srcAmount, "bought"); // price is 1
    }

    // Method: withdraw X or all, sell exact amount
    // Works for both partial & full
    function _createWithdrawCollateralAndSwapBundle(
        MarketParams memory marketParams,
        address destToken,
        uint256 srcAmount,
        address receiver
    ) internal {
        bundle.push(_morphoWithdrawCollateral(marketParams, srcAmount, address(paraswapModule)));
        bundle.push(_sell(marketParams.collateralToken, destToken, srcAmount, srcAmount, false, receiver));
    }

    /* WITHDRAW AND SWAP */

    function testPartialWithdrawAndSwap(uint256 supplyAmount, uint256 ratio) public {
        supplyAmount = bound(supplyAmount, MIN_AMOUNT, MAX_AMOUNT);

        _supply(marketParams, supplyAmount, USER);

        ratio = bound(ratio, MIN_RATIO, MAX_RATIO);
        uint256 srcAmount = supplyAmount * ratio / WAD;
        _createPartialWithdrawAndSwapBundle(marketParams, address(loanToken2), srcAmount, USER);

        skip(2 days);

        vm.prank(USER);
        bundler.multicall(bundle);

        assertEq(morpho.expectedSupplyAssets(marketParams, USER), supplyAmount - srcAmount, "sold");
        assertEq(loanToken2.balanceOf(USER), srcAmount, "bought"); // price is 1
    }

    // Method: withdraw X, sell exact amount
    function _createPartialWithdrawAndSwapBundle(
        MarketParams memory marketParams,
        address destToken,
        uint256 assetsToWithdraw,
        address receiver
    ) internal {
        bundle.push(_morphoWithdraw(marketParams, assetsToWithdraw, 0, type(uint256).max, address(paraswapModule)));
        bundle.push(_sell(marketParams.loanToken, destToken, assetsToWithdraw, assetsToWithdraw, false, receiver));
    }

    function testFullWithdrawAndSwap(uint256 supplyAmount) public {
        supplyAmount = bound(supplyAmount, MIN_AMOUNT, MAX_AMOUNT);

        _supply(marketParams, supplyAmount, USER);

        _createFullWithdrawAndSwapBundle(USER, marketParams, address(loanToken2), USER);

        skip(2 days);

        vm.prank(USER);
        bundler.multicall(bundle);

        assertEq(morpho.expectedSupplyAssets(marketParams, USER), 0, "sold");
        assertEq(loanToken2.balanceOf(USER), supplyAmount, "bought");
    }

    // Method: withdraw all, sell exact amount (replaced by current balance by paraswap module)
    function _createFullWithdrawAndSwapBundle(
        address user,
        MarketParams memory marketParams,
        address destToken,
        address receiver
    ) internal {
        uint256 sharesToWithdraw = morpho.supplyShares(marketParams.id(), user);
        uint256 currentAssets = morpho.expectedSupplyAssets(marketParams, user);
        bundle.push(_morphoWithdraw(marketParams, 0, sharesToWithdraw, 0, address(paraswapModule)));
        // Sell amount will be adjusted inside the paraswap module to the current balance
        bundle.push(_sell(marketParams.loanToken, destToken, currentAssets, currentAssets, true, receiver));
    }

    /* SUPPLY SWAP */

    function testPartialSupplySwap(uint256 supplyAmount, uint256 ratio) public {
        supplyAmount = bound(supplyAmount, MIN_AMOUNT, MAX_AMOUNT);

        _supply(marketParams, supplyAmount, USER);

        ratio = bound(ratio, MIN_RATIO, MAX_RATIO);
        uint256 srcAmount = supplyAmount * ratio / WAD;
        _createPartialSupplySwapBundle(USER, marketParams, marketParamsLoan2, address(loanToken2), srcAmount);

        skip(2 days);

        vm.prank(USER);
        bundler.multicall(bundle);

        assertEq(morpho.expectedSupplyAssets(marketParams, USER), supplyAmount - srcAmount, "withdrawn");
        assertEq(morpho.expectedSupplyAssets(marketParamsLoan2, USER), srcAmount, "supplied");
    }

    // Method: withdraw X, sell exact amount, supply all
    function _createPartialSupplySwapBundle(
        address user,
        MarketParams memory sourceParams,
        MarketParams memory destParams,
        address destToken,
        uint256 assetsToWithdraw
    ) internal {
        _createPartialWithdrawAndSwapBundle(sourceParams, destToken, assetsToWithdraw, address(genericModule1));
        bundle.push(_morphoSupply(destParams, type(uint256).max, 0, 0, user, hex""));
    }

    function testFullSupplySwap(uint256 supplyAmount) public {
        supplyAmount = bound(supplyAmount, MIN_AMOUNT, MAX_AMOUNT);

        _supply(marketParams, supplyAmount, USER);

        _createFullSupplySwapBundle(USER, marketParams, marketParamsLoan2);

        skip(2 days);

        vm.prank(USER);
        bundler.multicall(bundle);

        assertEq(morpho.expectedSupplyAssets(marketParams, USER), 0, "withdrawn");
        assertEq(morpho.expectedSupplyAssets(marketParamsLoan2, USER), supplyAmount, "supplied");
    }

    // Method: withdraw all, sell all, supply all
    function _createFullSupplySwapBundle(address user, MarketParams memory sourceParams, MarketParams memory destParams)
        internal
    {
        _createFullWithdrawAndSwapBundle(user, sourceParams, destParams.loanToken, address(genericModule1));
        bundle.push(_morphoSupply(destParams, type(uint256).max, 0, 0, user, hex""));
    }

    /* COLLATERAL SWAP */

    function testPartialCollateralSwap(uint256 borrowAmount, uint256 ratio) public {
        borrowAmount = bound(borrowAmount, MIN_AMOUNT, MAX_AMOUNT);
        uint256 collateralAmount = borrowAmount * 2;

        _supplyCollateral(marketParams, collateralAmount, SUPPLIER); // Need extra collateral for flashloan
        _supply(marketParams, borrowAmount, SUPPLIER);
        _supply(marketParamsCollateral2, borrowAmount, SUPPLIER);
        _supplyCollateral(marketParams, collateralAmount, USER);
        _borrow(marketParams, borrowAmount, USER);

        loanToken.setBalance(USER, 0);

        ratio = bound(ratio, MIN_RATIO, MAX_RATIO);
        uint256 borrowAssetsToTransfer = borrowAmount * ratio / WAD;
        uint256 collateralToSwap = collateralAmount * ratio / WAD;
        _createPartialCollateralSwapBundle(
            USER, marketParams, marketParamsCollateral2, collateralToSwap, borrowAssetsToTransfer
        );

        skip(0.1 days);

        uint256 borrowAssetsBefore = morpho.expectedBorrowAssets(marketParams, USER);

        vm.prank(USER);
        bundler.multicall(bundle);

        assertEq(morpho.collateral(marketParams.id(), USER), collateralAmount - collateralToSwap, "collateral 1");
        assertEq(morpho.collateral(marketParamsCollateral2.id(), USER), collateralToSwap, "collateral 2");
        assertEq(morpho.expectedBorrowAssets(marketParams, USER), borrowAssetsBefore - borrowAssetsToTransfer, "loan 1");
        assertEq(morpho.expectedBorrowAssets(marketParamsCollateral2, USER), borrowAssetsToTransfer, "loan 2");
    }

    // Method: repay, withdraw collateral, sell exact collateral, supply collateral, borrow.
    // Sell amount will be adjusted.
    function _createPartialCollateralSwapBundle(
        address user,
        MarketParams memory sourceParams,
        MarketParams memory destParams,
        uint256 collateralToSwap,
        uint256 borrowAssetsToTransfer
    ) internal {
        callbackBundle.push(_morphoWithdrawCollateral(sourceParams, collateralToSwap, address(paraswapModule)));
        callbackBundle.push(
            _sell(
                sourceParams.collateralToken,
                destParams.collateralToken,
                collateralToSwap,
                collateralToSwap,
                false,
                address(genericModule1)
            )
        );
        callbackBundle.push(_morphoSupplyCollateral(destParams, type(uint256).max, user, hex""));
        callbackBundle.push(
            _morphoBorrow(destParams, borrowAssetsToTransfer, 0, type(uint256).max, address(genericModule1))
        );
        bundle.push(_morphoRepay(sourceParams, borrowAssetsToTransfer, 0, 0, user));
    }

    function testFullCollateralSwap(uint256 borrowAmount) public {
        borrowAmount = bound(borrowAmount, MIN_AMOUNT, MAX_AMOUNT);
        uint256 collateralAmount = borrowAmount * 2;

        _supplyCollateral(marketParams, collateralAmount, SUPPLIER); // Need extra collateral for flashloan
        _supply(marketParams, borrowAmount, SUPPLIER);
        _supply(marketParamsCollateral2, borrowAmount * 2, SUPPLIER);
        _supplyCollateral(marketParams, collateralAmount, USER);
        _borrow(marketParams, borrowAmount, address(USER));

        loanToken.setBalance(USER, 0);

        _createFullCollateralSwapBundle(USER, marketParams, marketParamsCollateral2);

        skip(2 days);

        uint256 expectedDebt = morpho.expectedBorrowAssets(marketParams, USER);

        vm.prank(USER);
        bundler.multicall(bundle);

        assertEq(morpho.collateral(marketParams.id(), USER), 0);
        assertEq(morpho.collateral(marketParamsCollateral2.id(), USER), collateralAmount);
        assertEq(morpho.expectedBorrowAssets(marketParams, USER), 0);
        assertEq(morpho.expectedBorrowAssets(marketParamsCollateral2, USER), expectedDebt);
    }

    // Method: flashloan, sell exact collateral, supply collateral, borrow more than necessary from destMarket, repay
    // all shares on sourceMarket, repay remainnig balance on destMarket, withdraw collateral
    // Limitation: fails if Morpho does not hold 2 * collateral to swap
    // Alternative: repay, withdrawCollateral, swap, supplyCollateral,
    // borrowAmountFromMarketShares(market2,market1,shares+N)
    // Limitations: N required (repay lowers share price) & must be determined, last borrow can revert because +N made
    // user liquidatable
    function _createFullCollateralSwapBundle(
        address user,
        MarketParams memory sourceParams,
        MarketParams memory destParams
    ) internal {
        uint256 borrowShares = morpho.borrowShares(sourceParams.id(), user);
        uint256 collateralToSwap = morpho.collateral(sourceParams.id(), user);
        uint256 overestimatedDebtToRepay = morpho.expectedBorrowAssets(sourceParams, user) * 101 / 100;

        callbackBundle.push(
            _erc20Transfer(sourceParams.collateralToken, address(paraswapModule), collateralToSwap, genericModule1)
        );
        callbackBundle.push(
            _sell(
                sourceParams.collateralToken,
                destParams.collateralToken,
                collateralToSwap,
                collateralToSwap,
                true,
                address(genericModule1)
            )
        );
        callbackBundle.push(_morphoSupplyCollateral(destParams, type(uint256).max, user, hex""));
        callbackBundle.push(
            _morphoBorrow(destParams, overestimatedDebtToRepay, 0, type(uint256).max, address(genericModule1))
        );
        callbackBundle.push(_morphoRepay(sourceParams, 0, borrowShares, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoRepay(destParams, type(uint256).max, 0, 0, user, hex""));
        callbackBundle.push(_morphoWithdrawCollateral(sourceParams, collateralToSwap, address(genericModule1)));
        bundle.push(_morphoFlashLoan(sourceParams.collateralToken, collateralToSwap));
    }

    /* DEBT SWAP */

    function testPartialDebtSwap(uint256 borrowAmount, uint256 ratio) public {
        borrowAmount = bound(borrowAmount, MIN_AMOUNT, MAX_AMOUNT);
        uint256 collateralAmount = borrowAmount * 2;

        _supply(marketParams, borrowAmount, SUPPLIER);
        _supply(marketParamsLoan2, borrowAmount * 2, SUPPLIER);
        _supplyCollateral(marketParams, collateralAmount, USER);
        _borrow(marketParams, borrowAmount, address(USER));
        loanToken.setBalance(USER, 0);

        ratio = bound(ratio, MIN_RATIO, MAX_RATIO);
        uint256 debtToRepay = borrowAmount * ratio / WAD;
        uint256 collateralToTransfer = collateralAmount * ratio / WAD;
        _createPartialDebtSwapBundle(USER, marketParams, marketParamsLoan2, debtToRepay, collateralToTransfer);

        skip(2 days);

        uint256 expectedDebt = morpho.expectedBorrowAssets(marketParams, USER);

        vm.prank(USER);
        bundler.multicall(bundle);

        assertEq(morpho.collateral(marketParams.id(), USER), collateralAmount - collateralToTransfer, "collateral 1");
        assertEq(morpho.collateral(marketParamsLoan2.id(), USER), collateralToTransfer, "collateral 2");
        assertEq(morpho.expectedBorrowAssets(marketParams, USER), expectedDebt - debtToRepay, "loan 1");
        assertEq(morpho.expectedBorrowAssets(marketParamsLoan2, USER), debtToRepay, "loan 2"); // price is 1
    }

    // Method: supply collateral, borrow too much, buy exact, repay debt, repay leftover borrow, withdraw collateral
    // Issue: wasteful, must borrow too much
    function _createPartialDebtSwapBundle(
        address user,
        MarketParams memory sourceParams,
        MarketParams memory destParams,
        uint256 toRepay,
        uint256 collateralToTransfer
    ) internal {
        // overborrow to account for slippage
        // must keep 1 in balance so that second repay never fails
        uint256 toSell = toRepay * 101 / 100;
        uint256 toBorrow = toRepay * 101 / 100 + 1;

        callbackBundle.push(_morphoBorrow(destParams, toBorrow, 0, type(uint256).max, address(paraswapModule)));
        callbackBundle.push(
            _buy(destParams.loanToken, sourceParams.loanToken, toSell, toRepay, 0, address(genericModule1))
        );
        callbackBundle.push(_morphoRepay(sourceParams, type(uint256).max, 0, 0, user, hex""));
        callbackBundle.push(_morphoRepay(destParams, type(uint256).max, 0, 0, user, hex""));
        callbackBundle.push(_morphoWithdrawCollateral(sourceParams, collateralToTransfer, address(genericModule1)));
        bundle.push(_morphoSupplyCollateral(destParams, collateralToTransfer, user));
    }

    function testFullDebtSwap(uint256 borrowAmount) public {
        borrowAmount = bound(borrowAmount, MIN_AMOUNT, MAX_AMOUNT);
        uint256 collateralAmount = borrowAmount * 2;

        _supply(marketParams, borrowAmount, SUPPLIER);
        _supply(marketParamsLoan2, borrowAmount * 2, SUPPLIER);
        _supplyCollateral(marketParams, collateralAmount, USER);
        _borrow(marketParams, borrowAmount, address(USER));
        loanToken.setBalance(USER, 0);

        _createFullDebtSwapBundle(USER, marketParams, marketParamsLoan2);

        skip(2 days);

        uint256 expectedDebt = morpho.expectedBorrowAssets(marketParams, USER);

        vm.prank(USER);
        bundler.multicall(bundle);

        assertEq(morpho.collateral(marketParams.id(), USER), 0, "collateral 1");
        assertEq(morpho.collateral(marketParamsLoan2.id(), USER), collateralAmount, "collateral 2");
        assertEq(morpho.expectedBorrowAssets(marketParams, USER), 0, "loan 1");
        assertEq(morpho.expectedBorrowAssets(marketParamsLoan2, USER), expectedDebt, "loan 2");
    }

    // Method: supply collateral, borrow too much, buy exact, repay debt, repay leftover borrow, withdraw collateral
    function _createFullDebtSwapBundle(address user, MarketParams memory sourceParams, MarketParams memory destParams)
        internal
    {
        uint256 collateral = morpho.collateral(sourceParams.id(), user);
        uint256 borrowShares = morpho.borrowShares(sourceParams.id(), user);
        // will be adjusted
        uint256 toRepay = morpho.expectedBorrowAssets(sourceParams, user);
        // overborrow to account for slippage
        uint256 toBorrow = toRepay * 101 / 100;

        callbackBundle.push(_morphoBorrow(destParams, toBorrow, 0, type(uint256).max, address(paraswapModule)));
        // Buy amount will be adjusted inside the paraswap  to the current debt on sourceParams
        callbackBundle.push(
            _buyMorphoDebt(destParams.loanToken, toBorrow, toRepay, sourceParams, address(genericModule1))
        );
        callbackBundle.push(_morphoRepay(sourceParams, 0, borrowShares, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoRepay(destParams, type(uint256).max, 0, 0, user, hex""));
        callbackBundle.push(_morphoWithdrawCollateral(sourceParams, collateral, address(genericModule1)));
        bundle.push(_morphoSupplyCollateral(destParams, collateral, user));
    }

    /* REPAY WITH COLLATERAL */

    function testPartialRepayWithCollateral(uint256 borrowAmount, uint256 ratio) public {
        borrowAmount = bound(borrowAmount, MIN_AMOUNT, MAX_AMOUNT);
        uint256 collateralAmount = borrowAmount * 2;

        _supplyCollateral(marketParams, collateralAmount, SUPPLIER); // Need extra collateral for flashloan
        _supply(marketParams, borrowAmount, SUPPLIER);
        _supplyCollateral(marketParams, collateralAmount, USER);
        _borrow(marketParams, borrowAmount, address(USER));

        loanToken.setBalance(USER, 0);

        ratio = bound(ratio, MIN_RATIO, MAX_RATIO);
        uint256 assetsToRepay = borrowAmount * ratio / WAD;
        _createPartialRepayWithCollateralBundle(USER, marketParams, assetsToRepay);

        skip(2 days);

        uint256 expectedDebt = morpho.expectedBorrowAssets(marketParams, USER);

        vm.prank(USER);
        bundler.multicall(bundle);

        assertEq(morpho.collateral(marketParams.id(), USER), collateralAmount - assetsToRepay, "collateral");
        assertEq(morpho.expectedBorrowAssets(marketParams, USER), expectedDebt - assetsToRepay, "loan");
    }

    // Method: flashloan all current collateral, buy exact debt, repay debt, supply remaining collateral balance,
    // withdraw initial collateral
    // Limitation: fails if Morpho does not hold 2 * all collateral
    function _createPartialRepayWithCollateralBundle(
        address user,
        MarketParams memory marketParams,
        uint256 assetsToRepay
    ) internal {
        uint256 collateral = morpho.collateral(marketParams.id(), user);

        callbackBundle.push(
            _erc20Transfer(marketParams.collateralToken, address(paraswapModule), collateral, genericModule1)
        );
        callbackBundle.push(
            _buy(
                marketParams.collateralToken,
                marketParams.loanToken,
                collateral,
                assetsToRepay,
                0,
                address(genericModule1)
            )
        );
        callbackBundle.push(_morphoRepay(marketParams, assetsToRepay, 0, 0, user, hex""));
        // Cannot compute collateral - (remaining collateral), which would be the net amount to withdraw.
        // So do it in 2 steps: supply remaining collateral, then withdraw flashloaned amount.
        callbackBundle.push(_morphoSupplyCollateral(marketParams, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoWithdrawCollateral(marketParams, collateral, address(genericModule1)));
        bundle.push(_morphoFlashLoan(marketParams.collateralToken, collateral));
    }

    function testFullRepayWithCollateral(uint256 borrowAmount) public {
        borrowAmount = bound(borrowAmount, MIN_AMOUNT, MAX_AMOUNT);
        uint256 collateralAmount = borrowAmount * 2;

        _supplyCollateral(marketParams, collateralAmount, SUPPLIER); // Need extra collateral for flashloan
        _supply(marketParams, borrowAmount, SUPPLIER);
        _supplyCollateral(marketParams, collateralAmount, USER);
        _borrow(marketParams, borrowAmount, address(USER));

        loanToken.setBalance(USER, 0);

        _createFullRepayWithCollateralBundle(USER, marketParams);

        skip(2 days);

        uint256 expectedDebt = morpho.expectedBorrowAssets(marketParams, USER);

        vm.prank(USER);
        bundler.multicall(bundle);

        assertEq(morpho.collateral(marketParams.id(), USER), collateralAmount - expectedDebt, "collateral");
        assertEq(morpho.expectedBorrowAssets(marketParams, USER), 0, "loan");
    }

    // Method: flashloan all current collateral, buy exact debt, repay debt, supply remaining collateral balance,
    // withdraw initial collateral
    // Limitation: fails if Morpho does not hold 2 * all collateral
    function _createFullRepayWithCollateralBundle(address user, MarketParams memory marketParams) internal {
        uint256 collateral = morpho.collateral(marketParams.id(), user);
        uint256 assetsToBuy = collateral; // price is 1
        uint256 borrowShares = morpho.borrowShares(marketParams.id(), USER);

        callbackBundle.push(
            _erc20Transfer(marketParams.collateralToken, address(paraswapModule), collateral, genericModule1)
        );
        // Buy amount will be adjusted inside the paraswap module to the current debt
        callbackBundle.push(
            _buyMorphoDebt(marketParams.collateralToken, collateral, assetsToBuy, marketParams, address(genericModule1))
        );
        callbackBundle.push(_morphoRepay(marketParams, 0, borrowShares, type(uint256).max, user, hex""));
        // Cannot compute collateral - (remaining collateral), which would be the net amount to withdraw.
        // So do it in 2 steps: supply remaining collateral, then withdraw flashloaned amount.
        callbackBundle.push(_morphoSupplyCollateral(marketParams, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoWithdrawCollateral(marketParams, collateral, address(genericModule1)));
        bundle.push(_morphoFlashLoan(marketParams.collateralToken, collateral));
    }
}
