// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";

import "./helpers/LocalTest.sol";
import {IAugustusRegistry} from "../src/interfaces/IAugustusRegistry.sol";
import {MathLib} from "../lib/morpho-blue/src/libraries/MathLib.sol";

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

    MarketParams internal marketParamsAll2;
    Id internal idAll2;

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

        // Market with new loan token

        marketParamsLoan2 =
            MarketParams(address(loanToken2), address(collateralToken), address(oracle), address(irm), LLTV);
        idLoan2 = marketParamsLoan2.id();

        vm.prank(OWNER);
        morpho.createMarket(marketParamsLoan2);

        // New collateral token

        collateralToken2 = new ERC20Mock("collateral2", "C2");
        vm.label(address(collateralToken2), "collateralToken2");

        // Market with new collateral token
        marketParamsCollateral2 =
            MarketParams(address(loanToken), address(collateralToken2), address(oracle), address(irm), LLTV);
        idCollateral2 = marketParamsCollateral2.id();

        vm.prank(OWNER);
        morpho.createMarket(marketParamsCollateral2);

        // Market with both new loan and collateral token

        marketParamsAll2 =
            MarketParams(address(loanToken2), address(collateralToken2), address(oracle), address(irm), LLTV);
        idAll2 = marketParamsAll2.id();

        vm.prank(OWNER);
        morpho.createMarket(marketParamsAll2);

        // Approvals

        vm.startPrank(SUPPLIER);
        loanToken2.approve(address(morpho), type(uint256).max);
        loanToken.approve(address(morpho), type(uint256).max);
        collateralToken2.approve(address(morpho), type(uint256).max);

        vm.startPrank(USER);
        morpho.setAuthorization(address(generalAdapter1), true);
        collateralToken.approve(address(morpho), type(uint256).max);
        loanToken.approve(address(morpho), type(uint256).max);
        vm.stopPrank();
    }

    function _buyMorphoDebt(
        address srcToken,
        uint256 maxSrcAmount,
        uint256 destAmount,
        MarketParams memory marketParams,
        address onBehalf,
        address receiver
    ) internal view returns (Call memory) {
        uint256 fromAmountOffset = 4 + 32 + 32;
        uint256 toAmountOffset = fromAmountOffset + 32;
        return _call(
            paraswapAdapter,
            abi.encodeCall(
                paraswapAdapter.buyMorphoDebt,
                (
                    address(augustus),
                    abi.encodeCall(augustus.mockBuy, (srcToken, marketParams.loanToken, maxSrcAmount, destAmount)),
                    srcToken,
                    marketParams,
                    Offsets({exactAmount: toAmountOffset, limitAmount: fromAmountOffset, quotedAmount: 0}),
                    onBehalf,
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
        bundler3.multicall(bundle);

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
        bundle.push(_morphoWithdrawCollateral(marketParams, srcAmount, address(paraswapAdapter)));
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
        bundler3.multicall(bundle);

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
        bundle.push(_morphoWithdraw(marketParams, assetsToWithdraw, 0, 0, address(paraswapAdapter)));
        bundle.push(_sell(marketParams.loanToken, destToken, assetsToWithdraw, assetsToWithdraw, false, receiver));
    }

    function testFullWithdrawAndSwap(uint256 supplyAmount) public {
        supplyAmount = bound(supplyAmount, MIN_AMOUNT, MAX_AMOUNT);

        _supply(marketParams, supplyAmount, USER);

        _createFullWithdrawAndSwapBundle(USER, marketParams, address(loanToken2), USER);

        skip(2 days);

        vm.prank(USER);
        bundler3.multicall(bundle);

        assertEq(morpho.expectedSupplyAssets(marketParams, USER), 0, "sold");
        assertEq(loanToken2.balanceOf(USER), supplyAmount, "bought");
    }

    // Method: withdraw all, sell exact amount (replaced by current balance by paraswap adapter)
    function _createFullWithdrawAndSwapBundle(
        address user,
        MarketParams memory marketParams,
        address destToken,
        address receiver
    ) internal {
        uint256 currentAssets = morpho.expectedSupplyAssets(marketParams, user);
        bundle.push(_morphoWithdraw(marketParams, 0, type(uint256).max, 0, address(paraswapAdapter)));
        // Sell amount will be adjusted inside the paraswap adapter to the current balance
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
        bundler3.multicall(bundle);

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
        _createPartialWithdrawAndSwapBundle(sourceParams, destToken, assetsToWithdraw, address(generalAdapter1));
        bundle.push(_morphoSupply(destParams, type(uint256).max, 0, type(uint256).max, user, hex""));
    }

    function testFullSupplySwap(uint256 supplyAmount) public {
        supplyAmount = bound(supplyAmount, MIN_AMOUNT, MAX_AMOUNT);

        _supply(marketParams, supplyAmount, USER);

        _createFullSupplySwapBundle(USER, marketParams, marketParamsLoan2);

        skip(2 days);

        vm.prank(USER);
        bundler3.multicall(bundle);

        assertEq(morpho.expectedSupplyAssets(marketParams, USER), 0, "withdrawn");
        assertEq(morpho.expectedSupplyAssets(marketParamsLoan2, USER), supplyAmount, "supplied");
    }

    // Method: withdraw all, sell all, supply all
    function _createFullSupplySwapBundle(address user, MarketParams memory sourceParams, MarketParams memory destParams)
        internal
    {
        _createFullWithdrawAndSwapBundle(user, sourceParams, destParams.loanToken, address(generalAdapter1));
        bundle.push(_morphoSupply(destParams, type(uint256).max, 0, type(uint256).max, user, hex""));
    }

    /* COLLATERAL SWAP */

    function testPartialCollateralSwap(uint256 borrowAmount, uint256 ratio) public {
        borrowAmount = bound(borrowAmount, MIN_AMOUNT, MAX_AMOUNT);
        uint256 collateralAmount = borrowAmount * 2;

        _supply(marketParams, borrowAmount, SUPPLIER);
        _supply(marketParamsCollateral2, borrowAmount, SUPPLIER);
        _supplyCollateral(marketParams, collateralAmount, USER);
        _borrow(marketParams, borrowAmount, USER);

        deal(address(loanToken), USER, 0);

        ratio = bound(ratio, MIN_RATIO, MAX_RATIO);
        uint256 borrowAssetsToTransfer = borrowAmount * ratio / WAD;
        uint256 collateralToSwap = collateralAmount * ratio / WAD;
        _createPartialCollateralSwapBundle(
            USER, marketParams, marketParamsCollateral2, collateralToSwap, borrowAssetsToTransfer
        );

        skip(0.1 days);

        uint256 borrowAssetsBefore = morpho.expectedBorrowAssets(marketParams, USER);

        vm.prank(USER);
        bundler3.multicall(bundle);

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
        callbackBundle.push(_morphoWithdrawCollateral(sourceParams, collateralToSwap, address(paraswapAdapter)));
        callbackBundle.push(
            _sell(
                sourceParams.collateralToken,
                destParams.collateralToken,
                collateralToSwap,
                collateralToSwap,
                false,
                address(generalAdapter1)
            )
        );
        callbackBundle.push(_morphoSupplyCollateral(destParams, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoBorrow(destParams, borrowAssetsToTransfer, 0, 0, address(generalAdapter1)));
        bundle.push(
            _morphoRepay(sourceParams, borrowAssetsToTransfer, 0, type(uint256).max, user, abi.encode(callbackBundle))
        );
    }

    function testFullCollateralSwapUsingSupplyCollateralCallback(uint256 borrowAmount) public {
        borrowAmount = bound(borrowAmount, MIN_AMOUNT, MAX_AMOUNT);
        uint256 collateralAmount = borrowAmount * 2;

        _supply(marketParams, borrowAmount, SUPPLIER);
        _supply(marketParamsCollateral2, borrowAmount * 2, SUPPLIER);
        // Morpho must have extra destination collateral for the callback to work
        _supplyCollateral(marketParamsCollateral2, collateralAmount * 1 / 100, SUPPLIER);
        _supplyCollateral(marketParams, collateralAmount, USER);
        _borrow(marketParams, borrowAmount, address(USER));

        deal(address(loanToken), USER, 0);

        _createFullCollateralSwapBundleUsingSupplyCollateralCallback(USER, marketParams, marketParamsCollateral2);

        skip(2 days);

        uint256 expectedDebt = morpho.expectedBorrowAssets(marketParams, USER);

        vm.prank(USER);
        bundler3.multicall(bundle);

        assertEq(morpho.collateral(marketParams.id(), USER), 0);
        assertEq(morpho.collateral(marketParamsCollateral2.id(), USER), collateralAmount);
        assertEq(morpho.expectedBorrowAssets(marketParams, USER), 0);
        assertEq(morpho.expectedBorrowAssets(marketParamsCollateral2, USER), expectedDebt);
    }

    // Method: supply collateral first.
    // This is the recommended method unless the destination market has ~no extra collateral.
    // Steps: supply more destination collateral than necessary, borrow more from destination market than necessary,
    // repay all source market debt, repay residual loan asset to destination market, withdraw all source collateral,
    // sell all source collateral for destination collateral, supply all destination collateral, withdraw initially
    // supplied amount of destination collateral
    // Limitation 1: fails if Morpho does not hold the destination collateral overestimated amount.
    // Limitation 2: fails if the borrow asset overestimate is larger than available liquidity.
    function _createFullCollateralSwapBundleUsingSupplyCollateralCallback(
        address user,
        MarketParams memory sourceParams,
        MarketParams memory destParams
    ) internal {
        uint256 borrowAssetsOverestimate = morpho.expectedBorrowAssets(sourceParams, USER) * 101 / 100;
        uint256 destCollateralOverestimate = morpho.collateral(sourceParams.id(), USER) * 101 / 100;

        callbackBundle.push(_morphoBorrow(destParams, borrowAssetsOverestimate, 0, 0, address(generalAdapter1)));
        callbackBundle.push(_morphoRepay(sourceParams, 0, type(uint256).max, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoRepay(destParams, type(uint256).max, 0, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoWithdrawCollateral(sourceParams, type(uint256).max, address(paraswapAdapter)));
        callbackBundle.push(
            _sell(sourceParams.collateralToken, destParams.collateralToken, 1, 1, true, address(generalAdapter1))
        );
        // Must supply bought collateral to then be able to withdraw the exact initially supplied amount.
        callbackBundle.push(_morphoSupplyCollateral(destParams, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoWithdrawCollateral(destParams, destCollateralOverestimate, address(generalAdapter1)));

        bundle.push(_morphoSupplyCollateral(destParams, destCollateralOverestimate, user, abi.encode(callbackBundle)));
    }

    function testFullCollateralSwapUsingRepayCallback(uint256 borrowAmount) public {
        borrowAmount = bound(borrowAmount, MIN_AMOUNT, MAX_AMOUNT);
        uint256 collateralAmount = borrowAmount * 2;

        _supply(marketParams, borrowAmount, SUPPLIER);
        _supply(marketParamsCollateral2, borrowAmount * 2, SUPPLIER);
        _supplyCollateral(marketParams, collateralAmount, USER);
        _borrow(marketParams, borrowAmount, address(USER));

        deal(address(loanToken), USER, 0);

        _createFullCollateralSwapBundleUsingRepayCallback(USER, marketParams, marketParamsCollateral2);

        skip(2 days);

        uint256 expectedDebt = morpho.expectedBorrowAssets(marketParams, USER);

        vm.prank(USER);
        bundler3.multicall(bundle);

        assertEq(morpho.collateral(marketParams.id(), USER), 0);
        assertEq(morpho.collateral(marketParamsCollateral2.id(), USER), collateralAmount);
        assertEq(morpho.expectedBorrowAssets(marketParams, USER), 0);
        assertEq(morpho.expectedBorrowAssets(marketParamsCollateral2, USER), expectedDebt);
    }

    // Method: repay first.
    // Steps: repay all source market debt, withdraw all source collateral, sell all source collateral for destination
    // collateral, supply all destination collateral, borrow more than necessary from destination market, leave repay
    // callback, repay all residual assets on destination market
    // If the destination market has ~no extra collateral, and the user will not end up extremely close to destination
    // market LLTV, this is the recommended method.
    // Limitation 1: fails if the borrow asset overestimate makes the user cross LLTV.
    // Limitation 2: fails if the borrow asset overestimate is larger than available liquidity.
    function _createFullCollateralSwapBundleUsingRepayCallback(
        address user,
        MarketParams memory sourceParams,
        MarketParams memory destParams
    ) internal {
        uint256 borrowAssetsOverestimate = morpho.expectedBorrowAssets(sourceParams, USER) * 101 / 100;

        callbackBundle.push(_morphoWithdrawCollateral(sourceParams, type(uint256).max, address(paraswapAdapter)));
        callbackBundle.push(
            _sell(sourceParams.collateralToken, destParams.collateralToken, 1, 1, true, address(generalAdapter1))
        );
        callbackBundle.push(_morphoSupplyCollateral(destParams, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoBorrow(destParams, borrowAssetsOverestimate, 0, 0, address(generalAdapter1)));

        bundle.push(
            _morphoRepay(sourceParams, 0, type(uint256).max, type(uint256).max, user, abi.encode(callbackBundle))
        );

        bundle.push(_morphoRepay(destParams, type(uint256).max, 0, type(uint256).max, user, hex""));
    }

    function testFullCollateralSwapUsingFlashloan(uint256 borrowAmount) public {
        borrowAmount = bound(borrowAmount, MIN_AMOUNT, MAX_AMOUNT);
        uint256 collateralAmount = borrowAmount * 2;

        // Need extra collateral for flashloan
        _supplyCollateral(marketParamsCollateral2, collateralAmount * 2, SUPPLIER);
        _supply(marketParams, borrowAmount, SUPPLIER);
        _supply(marketParamsCollateral2, borrowAmount * 2, SUPPLIER);
        _supplyCollateral(marketParams, collateralAmount, USER);
        _borrow(marketParams, borrowAmount, address(USER));

        deal(address(loanToken), USER, 0);

        _createFullCollateralSwapBundleUsingFlashloan(USER, marketParams, marketParamsCollateral2);

        skip(2 days);

        uint256 expectedDebt = morpho.expectedBorrowAssets(marketParams, USER);

        vm.prank(USER);
        bundler3.multicall(bundle);

        assertEq(morpho.collateral(marketParams.id(), USER), 0);
        assertEq(morpho.collateral(marketParamsCollateral2.id(), USER), collateralAmount);
        assertEq(morpho.expectedBorrowAssets(marketParams, USER), 0);
        assertEq(morpho.expectedBorrowAssets(marketParamsCollateral2, USER), expectedDebt);
    }

    // Method: flashloan.
    // This is not a recommended method, but we leave it here for reference.
    // Steps: flashloan more destination collateral than necessary, supply all destination collateral, borrow more than
    // necessary from destination market, repay entire debt source market, repay residual balance on destination market,
    // withdraw all source collateral, sell all source collateral for destination collateral, supply all destination
    // collateral, withdraw flashloaned amount of destination collateral.
    // Limitation 1: fails if Morpho does not already hold enough destination collateral.
    // Limitation 2: fails if the borrow asset overestimate is larger than available liquidity.
    function _createFullCollateralSwapBundleUsingFlashloan(
        address user,
        MarketParams memory sourceParams,
        MarketParams memory destParams
    ) internal {
        uint256 borrowAssetsOverestimate = morpho.expectedBorrowAssets(sourceParams, USER) * 101 / 100;
        uint256 destCollateralOverestimate = morpho.collateral(sourceParams.id(), USER) * 101 / 100;

        callbackBundle.push(_morphoSupplyCollateral(destParams, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoBorrow(destParams, borrowAssetsOverestimate, 0, 0, address(generalAdapter1)));
        callbackBundle.push(_morphoRepay(sourceParams, 0, type(uint256).max, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoRepay(destParams, type(uint256).max, 0, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoWithdrawCollateral(sourceParams, type(uint256).max, address(paraswapAdapter)));
        callbackBundle.push(
            _sell(sourceParams.collateralToken, destParams.collateralToken, 1, 1, true, address(generalAdapter1))
        );
        // Must supply bought collateral to then be able to withdraw the exact flashloaned amount.
        callbackBundle.push(_morphoSupplyCollateral(destParams, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoWithdrawCollateral(destParams, destCollateralOverestimate, address(generalAdapter1)));
        bundle.push(
            _morphoFlashLoan(destParams.collateralToken, destCollateralOverestimate, abi.encode(callbackBundle))
        );
    }

    /* DEBT SWAP */

    function testPartialDebtSwap(uint256 borrowAmount, uint256 ratio) public {
        borrowAmount = bound(borrowAmount, MIN_AMOUNT, MAX_AMOUNT);
        uint256 collateralAmount = borrowAmount * 2;

        _supply(marketParams, borrowAmount, SUPPLIER);
        _supply(marketParamsLoan2, borrowAmount * 2, SUPPLIER);
        _supplyCollateral(marketParams, collateralAmount, USER);
        _borrow(marketParams, borrowAmount, address(USER));
        deal(address(loanToken), USER, 0);

        ratio = bound(ratio, MIN_RATIO, MAX_RATIO);
        uint256 debtToRepay = borrowAmount * ratio / WAD;
        uint256 collateralToTransfer = collateralAmount * ratio / WAD;
        _createPartialDebtSwapBundle(USER, marketParams, marketParamsLoan2, debtToRepay, collateralToTransfer);

        skip(2 days);

        uint256 expectedDebt = morpho.expectedBorrowAssets(marketParams, USER);

        vm.prank(USER);
        bundler3.multicall(bundle);

        assertEq(morpho.collateral(marketParams.id(), USER), collateralAmount - collateralToTransfer, "collateral 1");
        assertEq(morpho.collateral(marketParamsLoan2.id(), USER), collateralToTransfer, "collateral 2");
        assertEq(morpho.expectedBorrowAssets(marketParams, USER), expectedDebt - debtToRepay, "loan 1");
        assertEq(morpho.expectedBorrowAssets(marketParamsLoan2, USER), debtToRepay, "loan 2"); // price is 1
    }

    // Method: supply collateral, borrow too much, buy exact, repay debt, repay leftover borrow, withdraw collateral
    // Limitation: fails if the borrow asset overestimate is larger than available liquidity.
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

        callbackBundle.push(_morphoBorrow(destParams, toBorrow, 0, 0, address(paraswapAdapter)));
        callbackBundle.push(
            _buy(destParams.loanToken, sourceParams.loanToken, toSell, toRepay, 0, address(generalAdapter1))
        );
        callbackBundle.push(
            _erc20Transfer(address(destParams.loanToken), address(generalAdapter1), type(uint256).max, paraswapAdapter)
        );
        callbackBundle.push(_morphoRepay(sourceParams, type(uint256).max, 0, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoRepay(destParams, type(uint256).max, 0, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoWithdrawCollateral(sourceParams, collateralToTransfer, address(generalAdapter1)));
        bundle.push(_morphoSupplyCollateral(destParams, collateralToTransfer, user, abi.encode(callbackBundle)));
    }

    function testFullDebtSwap(uint256 borrowAmount) public {
        borrowAmount = bound(borrowAmount, MIN_AMOUNT, MAX_AMOUNT);
        uint256 collateralAmount = borrowAmount * 2;

        _supply(marketParams, borrowAmount, SUPPLIER);
        _supply(marketParamsLoan2, borrowAmount * 2, SUPPLIER);
        // Morpho must have extra collateral for the callback to work
        _supplyCollateral(marketParams, collateralAmount * 1 / 100, SUPPLIER);
        _supplyCollateral(marketParams, collateralAmount, USER);
        _borrow(marketParams, borrowAmount, address(USER));
        deal(address(loanToken), USER, 0);

        _createFullDebtSwapBundle(USER, marketParams, marketParamsLoan2);

        skip(2 days);

        uint256 expectedDebt = morpho.expectedBorrowAssets(marketParams, USER);

        vm.prank(USER);
        bundler3.multicall(bundle);

        assertEq(morpho.collateral(marketParams.id(), USER), 0, "collateral 1");
        assertEq(morpho.collateral(marketParamsLoan2.id(), USER), collateralAmount, "collateral 2");
        assertEq(morpho.expectedBorrowAssets(marketParams, USER), 0, "loan 1");
        assertEq(morpho.expectedBorrowAssets(marketParamsLoan2, USER), expectedDebt, "loan 2");
    }

    // Method: supply collateral first.
    // Steps: supply more collateral than necessary to destination market, borrow more destination loan assets than
    // necessary, buy exact source debt, repay source debt, repay leftover borrow, withdraw collateral from source
    // market, supply collateral to source market, withdraw overestimated collateral from destination market.
    // Limitation 1: fails if Morpho does not hold the destination collateral overestimated amount.
    // Limitation 2: fails if the borrow asset overestimate is larger than available liquidity.
    // Note: starting with a `morphoRepay` and continuing in the callback does not work well because the exact debt
    // amount becomes unknowable onchain. So at the 'buy exact debt' step, the user would have to overestimate the buy
    // amount, then sell the excess source loan asset previously after the callback has ended.
    // Note: starting with a collateral flashloan works but this method is simpler.
    function _createFullDebtSwapBundle(address user, MarketParams memory sourceParams, MarketParams memory destParams)
        internal
    {
        uint256 collateralOverestimate = morpho.collateral(sourceParams.id(), user) * 101 / 100;
        uint256 toRepay = morpho.expectedBorrowAssets(sourceParams, user);
        uint256 destBorrowAssetsOverestimate = toRepay * 101 / 100; // price is 1

        callbackBundle.push(_morphoBorrow(destParams, destBorrowAssetsOverestimate, 0, 0, address(paraswapAdapter)));
        // Buy amount will be adjusted inside the paraswap  to the current debt on sourceParams. Price is 1 in this
        // example.
        callbackBundle.push(
            _buyMorphoDebt(destParams.loanToken, toRepay, toRepay, sourceParams, user, address(generalAdapter1))
        );
        callbackBundle.push(
            _erc20Transfer(address(destParams.loanToken), address(generalAdapter1), type(uint256).max, paraswapAdapter)
        );
        callbackBundle.push(_morphoRepay(sourceParams, 0, type(uint256).max, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoRepay(destParams, type(uint256).max, 0, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoWithdrawCollateral(sourceParams, type(uint256).max, address(generalAdapter1)));
        // Must supply withdrawn collateral to then be able to withdraw the exact initially supplied amount.
        callbackBundle.push(_morphoSupplyCollateral(destParams, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoWithdrawCollateral(destParams, collateralOverestimate, address(generalAdapter1)));

        bundle.push(_morphoSupplyCollateral(destParams, collateralOverestimate, user, abi.encode(callbackBundle)));
    }

    /* DEBT&COLLATERAL SWAP */

    function testFullDebtAndCollateralSwap(uint256 borrowAmount) public {
        borrowAmount = bound(borrowAmount, MIN_AMOUNT, MAX_AMOUNT);
        uint256 collateralAmount = borrowAmount * 2;

        // Need extra collateral for flashloan
        _supplyCollateral(marketParams, collateralAmount, SUPPLIER);
        _supply(marketParams, borrowAmount, SUPPLIER);
        _supply(marketParamsAll2, borrowAmount * 2, SUPPLIER);
        _supplyCollateral(marketParams, collateralAmount, USER);
        _borrow(marketParams, borrowAmount, address(USER));

        deal(address(loanToken), USER, 0);

        _createFullDebtAndCollateralSwapBundle(USER, marketParams, marketParamsAll2);

        skip(2 days);

        uint256 expectedDebt = morpho.expectedBorrowAssets(marketParams, USER);

        vm.prank(USER);
        bundler3.multicall(bundle);

        assertEq(morpho.collateral(marketParams.id(), USER), 0);
        assertEq(morpho.collateral(marketParamsAll2.id(), USER), collateralAmount);
        assertEq(morpho.expectedBorrowAssets(marketParams, USER), 0);
        assertEq(morpho.expectedBorrowAssets(marketParamsAll2, USER), expectedDebt);
    }

    // Flashloan exact source collat amount, sell source collat for dest collat, supply dest collat, borrow dest loan
    // token (overestimated to repay overestimation of current source debt), buy source loan token with dest loan token,
    // repay source debt, repay dest debt, withdraw source collat
    // Limitation: same as full collateral swap bundle that uses flashloan
    // Alternative: supply more destination collateral than necessary, borrow more from destination than necessary, buy
    // exact source debt, repay exact source debt, repay leftover destination debt, withdraw all source collateral, sell
    // all source collateral for destination collateral, supply all destination collateral, withdraw initially supplied
    // amount of destination collateral.
    function _createFullDebtAndCollateralSwapBundle(
        address user,
        MarketParams memory sourceParams,
        MarketParams memory destParams
    ) internal {
        uint256 sourceBorrowShares = morpho.borrowShares(marketParams.id(), USER);
        uint256 sourceBorrowAssetsOverestimate = morpho.expectedBorrowAssets(marketParams, USER) * 101 / 100;
        uint256 sourceCollateral = morpho.collateral(marketParams.id(), USER);
        // Should be the expected amount of new debt necessary to buy the expected old debt
        uint256 destBorrowAssetsOverestimate = sourceBorrowAssetsOverestimate * 101 / 100;

        callbackBundle.push(
            _erc20Transfer(sourceParams.collateralToken, address(paraswapAdapter), sourceCollateral, generalAdapter1)
        );
        callbackBundle.push(
            _sell(
                sourceParams.collateralToken,
                destParams.collateralToken,
                sourceCollateral,
                sourceCollateral,
                true,
                address(generalAdapter1)
            )
        );
        callbackBundle.push(_morphoSupplyCollateral(destParams, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoBorrow(destParams, destBorrowAssetsOverestimate, 0, 0, address(paraswapAdapter)));

        // Buy amount will be adjusted inside the paraswap  to the current debt on sourceParams
        callbackBundle.push(
            _buyMorphoDebt(
                destParams.loanToken,
                destBorrowAssetsOverestimate,
                sourceBorrowAssetsOverestimate,
                sourceParams,
                user,
                address(generalAdapter1)
            )
        );
        callbackBundle.push(
            _erc20Transfer(address(destParams.loanToken), address(generalAdapter1), type(uint256).max, paraswapAdapter)
        );
        callbackBundle.push(_morphoRepay(sourceParams, 0, sourceBorrowShares, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoRepay(destParams, type(uint256).max, 0, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoWithdrawCollateral(sourceParams, sourceCollateral, address(generalAdapter1)));
        callbackBundle.push(
            _erc20Transfer(address(sourceParams.collateralToken), user, type(uint256).max, paraswapAdapter)
        );
        bundle.push(_morphoFlashLoan(sourceParams.collateralToken, sourceCollateral, abi.encode(callbackBundle)));
    }

    /* REPAY WITH COLLATERAL */

    function testPartialRepayWithCollateral(uint256 borrowAmount, uint256 ratio) public {
        borrowAmount = bound(borrowAmount, MIN_AMOUNT, MAX_AMOUNT);
        uint256 collateralAmount = borrowAmount * 2;

        // Need extra collateral for flashloan
        _supplyCollateral(marketParams, collateralAmount, SUPPLIER);
        _supply(marketParams, borrowAmount, SUPPLIER);
        _supplyCollateral(marketParams, collateralAmount, USER);
        _borrow(marketParams, borrowAmount, address(USER));

        deal(address(loanToken), USER, 0);

        ratio = bound(ratio, MIN_RATIO, MAX_RATIO);
        uint256 assetsToRepay = borrowAmount * ratio / WAD;
        _createPartialRepayWithCollateralBundle(USER, marketParams, assetsToRepay);

        skip(2 days);

        uint256 expectedDebt = morpho.expectedBorrowAssets(marketParams, USER);

        vm.prank(USER);
        bundler3.multicall(bundle);

        assertEq(morpho.collateral(marketParams.id(), USER), collateralAmount - assetsToRepay, "collateral");
        assertEq(morpho.expectedBorrowAssets(marketParams, USER), expectedDebt - assetsToRepay, "loan");
    }

    // Method: flashloan.
    // Steps: flashloan all current collateral, buy exact debt, repay debt, supply remaining collateral balance,
    // withdraw initial collateral
    // Limitation: fails if Morpho does not hold the user's collateral amount + the amount of collateral the user will
    // sell to rebuy his debt.
    // Note: starting with a supplyCollateral would not change the above limitation.
    function _createPartialRepayWithCollateralBundle(
        address user,
        MarketParams memory marketParams,
        uint256 assetsToRepay
    ) internal {
        uint256 collateral = morpho.collateral(marketParams.id(), user);

        callbackBundle.push(
            _erc20Transfer(marketParams.collateralToken, address(paraswapAdapter), collateral, generalAdapter1)
        );
        callbackBundle.push(
            _buy(
                marketParams.collateralToken,
                marketParams.loanToken,
                collateral,
                assetsToRepay,
                0,
                address(generalAdapter1)
            )
        );
        callbackBundle.push(
            _erc20Transfer(
                address(marketParams.collateralToken), address(generalAdapter1), type(uint256).max, paraswapAdapter
            )
        );
        callbackBundle.push(_morphoRepay(marketParams, assetsToRepay, 0, type(uint256).max, user, hex""));
        // Cannot compute collateral - (remaining collateral), which would be the net amount to withdraw.
        // So do it in 2 steps: supply remaining collateral, then withdraw flashloaned amount.
        callbackBundle.push(_morphoSupplyCollateral(marketParams, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoWithdrawCollateral(marketParams, collateral, address(generalAdapter1)));
        bundle.push(_morphoFlashLoan(marketParams.collateralToken, collateral, abi.encode(callbackBundle)));
    }

    function testFullRepayWithCollateral(uint256 borrowAmount) public {
        borrowAmount = bound(borrowAmount, MIN_AMOUNT, MAX_AMOUNT);
        uint256 collateralAmount = borrowAmount * 2;

        // Need extra collateral for flashloan
        _supplyCollateral(marketParams, collateralAmount, SUPPLIER);
        _supply(marketParams, borrowAmount, SUPPLIER);
        _supplyCollateral(marketParams, collateralAmount, USER);
        _borrow(marketParams, borrowAmount, address(USER));

        deal(address(loanToken), USER, 0);

        _createFullRepayWithCollateralBundle(USER, marketParams);

        skip(2 days);

        uint256 expectedDebt = morpho.expectedBorrowAssets(marketParams, USER);

        vm.prank(USER);
        bundler3.multicall(bundle);

        assertEq(morpho.collateral(marketParams.id(), USER), collateralAmount - expectedDebt, "collateral");
        assertEq(morpho.expectedBorrowAssets(marketParams, USER), 0, "loan");
    }

    // Method: flashloan.
    // Steps: flashloan all current collateral, buy exact debt, repay debt, supply remaining collateral balance,
    // withdraw initial collateral
    // Limitation: fails if Morpho does not hold the user's collateral amount + the amount of collateral the user will
    // sell to rebuy his debt.
    // Note: starting with a supplyCollateral would not change the above limitation.
    function _createFullRepayWithCollateralBundle(address user, MarketParams memory marketParams) internal {
        uint256 collateral = morpho.collateral(marketParams.id(), user);
        uint256 assetsToBuy = collateral; // price is 1

        callbackBundle.push(
            _erc20Transfer(marketParams.collateralToken, address(paraswapAdapter), collateral, generalAdapter1)
        );
        // Buy amount will be adjusted inside the paraswap adapter to the current debt
        callbackBundle.push(
            _buyMorphoDebt(
                marketParams.collateralToken, collateral, assetsToBuy, marketParams, user, address(generalAdapter1)
            )
        );
        callbackBundle.push(
            _erc20Transfer(
                address(marketParams.collateralToken), address(generalAdapter1), type(uint256).max, paraswapAdapter
            )
        );
        callbackBundle.push(_morphoRepay(marketParams, 0, type(uint256).max, type(uint256).max, user, hex""));
        // Cannot compute collateral - (remaining collateral), which would be the net amount to withdraw.
        // So do it in 2 steps: supply remaining collateral, then withdraw flashloaned amount.
        callbackBundle.push(_morphoSupplyCollateral(marketParams, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoWithdrawCollateral(marketParams, collateral, address(generalAdapter1)));
        bundle.push(_morphoFlashLoan(marketParams.collateralToken, collateral, abi.encode(callbackBundle)));
    }
}
