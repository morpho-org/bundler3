// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {
    Withdrawal, FlowCapsConfig, MAX_SETTABLE_FLOW_CAP, IPublicAllocator
} from "../src/interfaces/IPublicAllocator.sol";

import {SigUtils} from "./helpers/SigUtils.sol";
import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";
import {ErrorsLib as MorphoErrorsLib} from "../lib/morpho-blue/src/libraries/ErrorsLib.sol";
import {MarketParamsLib} from "../lib/morpho-blue/src/libraries/MarketParamsLib.sol";

import "./helpers/MetaMorphoLocalTest.sol";

contract MorphoModuleLocalTest is MetaMorphoLocalTest {
    using MathLib for uint256;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;
    using SharesMathLib for uint256;
    using MarketParamsLib for MarketParams;
    using BundlerLib for Bundler;

    function setUp() public override {
        super.setUp();

        vm.startPrank(USER);
        loanToken.approve(address(morpho), type(uint256).max);
        collateralToken.approve(address(morpho), type(uint256).max);
        loanToken.approve(address(genericModule1), type(uint256).max);
        collateralToken.approve(address(genericModule1), type(uint256).max);
        vm.stopPrank();

        vm.prank(LIQUIDATOR);
        loanToken.approve(address(genericModule1), type(uint256).max);
    }

    function approveERC20ToMorphoAndModule(address user) internal {
        vm.startPrank(user);
        loanToken.approve(address(morpho), type(uint256).max);
        collateralToken.approve(address(morpho), type(uint256).max);
        loanToken.approve(address(genericModule1), type(uint256).max);
        collateralToken.approve(address(genericModule1), type(uint256).max);
        vm.stopPrank();
    }

    function assumeOnBehalf(address onBehalf) internal view {
        vm.assume(onBehalf != address(0));
        vm.assume(onBehalf != address(morpho));
        vm.assume(onBehalf != address(genericModule1));
    }

    function testSetAuthorizationWithSig(uint256 privateKey, uint32 deadline) public {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);
        deadline = uint32(bound(deadline, block.timestamp + 1, type(uint32).max));

        bundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));
        bundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, true));

        bundler.multicall(bundle);

        assertTrue(morpho.isAuthorized(user, address(genericModule1)), "isAuthorized(user, genericModule1)");
    }

    function testSetAuthorizationWithSigRevert(uint256 privateKey, uint32 deadline) public {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);
        deadline = uint32(bound(deadline, block.timestamp + 1, type(uint32).max));

        bundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));
        bundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));

        vm.expectRevert(bytes(MorphoErrorsLib.INVALID_NONCE));
        bundler.multicall(bundle);
    }

    function testSupplyOnBehalfModuleAddress(uint256 assets) public {
        assets = bound(assets, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_morphoSupply(marketParams, assets, 0, 0, address(genericModule1)));

        vm.expectRevert(ErrorsLib.ModuleAddress.selector);
        bundler.multicall(bundle);
    }

    function testSupplyCollateralOnBehalfModuleAddress(uint256 assets) public {
        assets = bound(assets, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_morphoSupplyCollateral(marketParams, assets, address(genericModule1)));

        vm.expectRevert(ErrorsLib.ModuleAddress.selector);
        bundler.multicall(bundle);
    }

    function testRepayOnBehalfModuleAddress(uint256 assets) public {
        assets = bound(assets, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_morphoRepay(marketParams, assets, 0, 0, address(genericModule1)));

        vm.expectRevert(ErrorsLib.ModuleAddress.selector);
        bundler.multicall(bundle);
    }

    function _testSupply(uint256 amount, address onBehalf) internal view {
        assertEq(collateralToken.balanceOf(USER), 0, "collateral.balanceOf(USER)");
        assertEq(loanToken.balanceOf(USER), 0, "loan.balanceOf(USER)");

        assertEq(collateralToken.balanceOf(onBehalf), 0, "collateral.balanceOf(onBehalf)");
        assertEq(loanToken.balanceOf(onBehalf), 0, "loan.balanceOf(onBehalf)");

        assertEq(morpho.collateral(id, onBehalf), 0, "collateral(onBehalf)");
        assertEq(morpho.supplyShares(id, onBehalf), amount * SharesMathLib.VIRTUAL_SHARES, "supplyShares(onBehalf)");
        assertEq(morpho.borrowShares(id, onBehalf), 0, "borrowShares(onBehalf)");

        if (onBehalf != USER) {
            assertEq(morpho.collateral(id, USER), 0, "collateral(USER)");
            assertEq(morpho.supplyShares(id, USER), 0, "supplyShares(USER)");
            assertEq(morpho.borrowShares(id, USER), 0, "borrowShares(USER)");
        }
    }

    function testSupply(uint256 amount, address onBehalf) public {
        assumeOnBehalf(onBehalf);

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20TransferFrom(address(loanToken), amount));
        bundle.push(_morphoSupply(marketParams, amount, 0, 0, onBehalf));

        loanToken.setBalance(USER, amount);

        vm.prank(USER);
        bundler.multicall(bundle);

        _testSupply(amount, onBehalf);
    }

    function testSupplyMax(uint256 amount, address onBehalf) public {
        assumeOnBehalf(onBehalf);

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20TransferFrom(address(loanToken), amount));
        bundle.push(_morphoSupply(marketParams, type(uint256).max, 0, 0, onBehalf));

        loanToken.setBalance(USER, amount);

        vm.prank(USER);
        bundler.multicall(bundle);

        _testSupply(amount, onBehalf);
    }

    function testSupplyCallback(uint256 amount, address onBehalf) public {
        assumeOnBehalf(onBehalf);

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        callbackBundle.push(_erc20TransferFrom(address(loanToken), amount));

        bundle.push(_morphoSupply(marketParams, amount, 0, 0, onBehalf));

        loanToken.setBalance(USER, amount);

        vm.prank(USER);
        bundler.multicall(bundle, _hashBundles(callbackBundle));

        _testSupply(amount, onBehalf);
    }

    function _testSupplyCollateral(uint256 amount, address onBehalf) internal view {
        assertEq(collateralToken.balanceOf(USER), 0, "collateral.balanceOf(USER)");
        assertEq(loanToken.balanceOf(USER), 0, "loan.balanceOf(USER)");

        assertEq(collateralToken.balanceOf(onBehalf), 0, "collateral.balanceOf(onBehalf)");
        assertEq(loanToken.balanceOf(onBehalf), 0, "loan.balanceOf(onBehalf)");

        assertEq(morpho.collateral(id, onBehalf), amount, "collateral(onBehalf)");
        assertEq(morpho.supplyShares(id, onBehalf), 0, "supplyShares(onBehalf)");
        assertEq(morpho.borrowShares(id, onBehalf), 0, "borrowShares(onBehalf)");

        if (onBehalf != USER) {
            assertEq(morpho.collateral(id, USER), 0, "collateral(USER)");
            assertEq(morpho.supplyShares(id, USER), 0, "supplyShares(USER)");
            assertEq(morpho.borrowShares(id, USER), 0, "borrowShares(USER)");
        }
    }

    function testSupplyCollateral(uint256 amount, address onBehalf) public {
        assumeOnBehalf(onBehalf);

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20TransferFrom(address(collateralToken), amount));
        bundle.push(_morphoSupplyCollateral(marketParams, amount, onBehalf));

        collateralToken.setBalance(USER, amount);

        vm.prank(USER);
        bundler.multicall(bundle);

        _testSupplyCollateral(amount, onBehalf);
    }

    function testSupplyCollateralMax(uint256 amount, address onBehalf) public {
        assumeOnBehalf(onBehalf);

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20TransferFrom(address(collateralToken), amount));
        bundle.push(_morphoSupplyCollateral(marketParams, type(uint256).max, onBehalf));

        collateralToken.setBalance(USER, amount);

        vm.prank(USER);
        bundler.multicall(bundle);

        _testSupplyCollateral(amount, onBehalf);
    }

    function testWithdrawUnauthorized(uint256 withdrawnShares) public {
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.UnauthorizedSender.selector, address(this)));
        genericModule1.morphoWithdraw(marketParams, 0, withdrawnShares, 0, RECEIVER);
    }

    function testWithdraw(uint256 privateKey, uint256 amount, uint256 withdrawnShares) public {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);
        approveERC20ToMorphoAndModule(user);

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);
        uint256 expectedSupplyShares = amount.toSharesDown(0, 0);
        withdrawnShares = bound(withdrawnShares, 1, expectedSupplyShares);
        uint256 expectedWithdrawnAmount = withdrawnShares.toAssetsDown(amount, expectedSupplyShares);

        bundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));
        bundle.push(_morphoWithdraw(marketParams, 0, withdrawnShares, 0, user));

        loanToken.setBalance(user, amount);

        vm.startPrank(user);
        morpho.supply(marketParams, amount, 0, user, hex"");

        bundler.multicall(bundle);
        vm.stopPrank();

        assertEq(loanToken.balanceOf(user), expectedWithdrawnAmount, "loan.balanceOf(user)");
        assertEq(loanToken.balanceOf(address(genericModule1)), 0, "loan.balanceOf(address(genericModule1)");
        assertEq(
            loanToken.balanceOf(address(morpho)), amount - expectedWithdrawnAmount, "loan.balanceOf(address(morpho))"
        );

        assertEq(morpho.collateral(id, user), 0, "collateral(user)");
        assertEq(morpho.supplyShares(id, user), expectedSupplyShares - withdrawnShares, "supplyShares(user)");
        assertEq(morpho.borrowShares(id, user), 0, "borrowShares(user)");
    }

    function testBorrowUnauthorized(uint256 borrowedAssets) public {
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.UnauthorizedSender.selector, address(this)));
        genericModule1.morphoBorrow(marketParams, borrowedAssets, 0, type(uint256).max, RECEIVER);
    }

    function _testSupplyCollateralBorrow(address user, uint256 amount, uint256 collateralAmount) internal view {
        assertEq(collateralToken.balanceOf(RECEIVER), 0, "collateral.balanceOf(RECEIVER)");
        assertEq(loanToken.balanceOf(RECEIVER), amount, "loan.balanceOf(RECEIVER)");

        assertEq(morpho.collateral(id, user), collateralAmount, "collateral(user)");
        assertEq(morpho.supplyShares(id, user), 0, "supplyShares(user)");
        assertEq(morpho.borrowShares(id, user), amount * SharesMathLib.VIRTUAL_SHARES, "borrowShares(user)");

        if (RECEIVER != user) {
            assertEq(morpho.collateral(id, RECEIVER), 0, "collateral(RECEIVER)");
            assertEq(morpho.supplyShares(id, RECEIVER), 0, "supplyShares(RECEIVER)");
            assertEq(morpho.borrowShares(id, RECEIVER), 0, "borrowShares(RECEIVER)");

            assertEq(collateralToken.balanceOf(user), 0, "collateral.balanceOf(user)");
            assertEq(loanToken.balanceOf(user), 0, "loan.balanceOf(user)");
        }
    }

    function testSupplyCollateralBorrow(uint256 privateKey, uint256 amount) public {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);
        approveERC20ToMorphoAndModule(user);

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        loanToken.setBalance(address(this), amount);
        morpho.supply(marketParams, amount, 0, SUPPLIER, hex"");

        uint256 collateralAmount = amount.wDivUp(LLTV);

        bundle.push(_erc20TransferFrom(address(collateralToken), collateralAmount));
        bundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));
        bundle.push(_morphoSupplyCollateral(marketParams, collateralAmount, user));
        bundle.push(_morphoBorrow(marketParams, amount, 0, type(uint256).max, RECEIVER));

        collateralToken.setBalance(user, collateralAmount);

        vm.prank(user);
        bundler.multicall(bundle);

        _testSupplyCollateralBorrow(user, amount, collateralAmount);
    }

    function testSupplyCollateralBorrowViaCallback(uint256 privateKey, uint256 amount) public {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);
        approveERC20ToMorphoAndModule(user);

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        loanToken.setBalance(address(this), amount);
        morpho.supply(marketParams, amount, 0, SUPPLIER, hex"");

        uint256 collateralAmount = amount.wDivUp(LLTV);

        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));
        callbackBundle.push(_morphoBorrow(marketParams, amount, 0, type(uint256).max, RECEIVER));
        callbackBundle.push(_erc20TransferFrom(address(collateralToken), collateralAmount));

        bundle.push(_morphoSupplyCollateral(marketParams, collateralAmount, user));

        collateralToken.setBalance(user, collateralAmount);

        vm.prank(user);
        bundler.multicall(bundle, _hashBundles(callbackBundle));

        _testSupplyCollateralBorrow(user, amount, collateralAmount);
    }

    function testWithdrawCollateralUnauthorized(uint256 collateralAmount) public {
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.UnauthorizedSender.selector, address(this)));
        genericModule1.morphoWithdrawCollateral(marketParams, collateralAmount, RECEIVER);
    }

    function _testRepayWithdrawCollateral(address user, uint256 collateralAmount) internal view {
        assertEq(collateralToken.balanceOf(RECEIVER), collateralAmount, "collateral.balanceOf(RECEIVER)");
        assertEq(loanToken.balanceOf(RECEIVER), 0, "loan.balanceOf(RECEIVER)");

        assertEq(morpho.collateral(id, user), 0, "collateral(user)");
        assertEq(morpho.supplyShares(id, user), 0, "supplyShares(user)");
        assertEq(morpho.borrowShares(id, user), 0, "borrowShares(user)");

        if (RECEIVER != user) {
            assertEq(morpho.collateral(id, RECEIVER), 0, "collateral(RECEIVER)");
            assertEq(morpho.supplyShares(id, RECEIVER), 0, "supplyShares(RECEIVER)");
            assertEq(morpho.borrowShares(id, RECEIVER), 0, "borrowShares(RECEIVER)");

            assertEq(collateralToken.balanceOf(user), 0, "collateral.balanceOf(user)");
            assertEq(loanToken.balanceOf(user), 0, "loan.balanceOf(user)");
        }
    }

    function testRepayWithdrawCollateral(uint256 privateKey, uint256 amount) public {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);
        approveERC20ToMorphoAndModule(user);

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        loanToken.setBalance(address(this), amount);
        morpho.supply(marketParams, amount, 0, SUPPLIER, hex"");

        uint256 collateralAmount = amount.wDivUp(LLTV);

        collateralToken.setBalance(user, collateralAmount);
        vm.startPrank(user);
        morpho.supplyCollateral(marketParams, collateralAmount, user, hex"");
        morpho.borrow(marketParams, amount, 0, user, user);
        vm.stopPrank();

        bundle.push(_erc20TransferFrom(address(loanToken), amount));
        bundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));
        bundle.push(_morphoRepay(marketParams, amount, 0, 0, user));
        bundle.push(_morphoWithdrawCollateral(marketParams, collateralAmount, RECEIVER));

        vm.prank(user);
        bundler.multicall(bundle);

        _testRepayWithdrawCollateral(user, collateralAmount);
    }

    function testRepayMaxAndWithdrawCollateral(uint256 privateKey, uint256 amount) public {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);
        approveERC20ToMorphoAndModule(user);

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        loanToken.setBalance(address(this), amount);
        morpho.supply(marketParams, amount, 0, SUPPLIER, hex"");

        uint256 collateralAmount = amount.wDivUp(LLTV);

        collateralToken.setBalance(user, collateralAmount);
        vm.startPrank(user);
        morpho.supplyCollateral(marketParams, collateralAmount, user, hex"");
        morpho.borrow(marketParams, amount, 0, user, user);
        vm.stopPrank();

        bundle.push(_erc20TransferFrom(address(loanToken), amount));
        bundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));
        bundle.push(_morphoRepay(marketParams, type(uint256).max, 0, 0, user));
        bundle.push(_morphoWithdrawCollateral(marketParams, collateralAmount, RECEIVER));

        vm.prank(user);
        bundler.multicall(bundle);

        _testRepayWithdrawCollateral(user, collateralAmount);
    }

    function testRepayWithdrawCollateralViaCallback(uint256 privateKey, uint256 amount) public {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);
        approveERC20ToMorphoAndModule(user);

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        loanToken.setBalance(address(this), amount);
        morpho.supply(marketParams, amount, 0, SUPPLIER, hex"");

        uint256 collateralAmount = amount.wDivUp(LLTV);

        collateralToken.setBalance(user, collateralAmount);
        vm.startPrank(user);
        morpho.supplyCollateral(marketParams, collateralAmount, user, hex"");
        morpho.borrow(marketParams, amount, 0, user, user);
        vm.stopPrank();

        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));
        callbackBundle.push(_morphoWithdrawCollateral(marketParams, collateralAmount, RECEIVER));
        callbackBundle.push(_erc20TransferFrom(address(loanToken), amount));

        bundle.push(_morphoRepay(marketParams, amount, 0, 0, user));

        vm.prank(user);
        bundler.multicall(bundle, _hashBundles(callbackBundle));

        _testRepayWithdrawCollateral(user, collateralAmount);
    }

    struct BundleTransactionsVars {
        uint256 expectedSupplyShares;
        uint256 expectedBorrowShares;
        uint256 expectedTotalSupply;
        uint256 expectedTotalBorrow;
        uint256 expectedCollateral;
        uint256 expectedModuleLoanBalance;
        uint256 expectedModuleCollateralBalance;
        uint256 initialUserLoanBalance;
        uint256 initialUserCollateralBalance;
    }

    function testBundleTransactions(uint256 privateKey, uint256 size, uint256 seedAction, uint256 seedAmount) public {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);
        approveERC20ToMorphoAndModule(user);

        bundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));

        seedAction = bound(seedAction, 0, type(uint256).max - 30);
        seedAmount = bound(seedAmount, 0, type(uint256).max - 30);

        BundleTransactionsVars memory vars;

        for (uint256 i; i < size % 30; ++i) {
            uint256 actionId = uint256(keccak256(abi.encode(seedAmount + i))) % 11;
            uint256 amount = uint256(keccak256(abi.encode(seedAction + i)));
            if (actionId < 3) _addSupplyData(vars, amount, user);
            else if (actionId < 6) _addSupplyCollateralData(vars, amount, user);
            else if (actionId < 8) _addBorrowData(vars, amount);
            else if (actionId < 9) _addRepayData(vars, amount, user);
            else if (actionId < 10) _addWithdrawData(vars, amount);
            else if (actionId == 10) _addWithdrawCollateralData(vars, amount);
        }

        loanToken.setBalance(user, vars.initialUserLoanBalance);
        collateralToken.setBalance(user, vars.initialUserCollateralBalance);

        vm.prank(user);
        bundler.multicall(bundle);

        assertEq(morpho.supplyShares(id, user), vars.expectedSupplyShares, "User's supply shares");
        assertEq(morpho.borrowShares(id, user), vars.expectedBorrowShares, "User's borrow shares");
        assertEq(morpho.totalSupplyShares(id), vars.expectedSupplyShares, "Total supply shares");
        assertEq(morpho.totalBorrowShares(id), vars.expectedBorrowShares, "Total borrow shares");
        assertEq(morpho.totalSupplyAssets(id), vars.expectedTotalSupply, "Total supply");
        assertEq(morpho.totalBorrowAssets(id), vars.expectedTotalBorrow, "Total borrow");
        assertEq(morpho.collateral(id, user), vars.expectedCollateral, "User's collateral");

        assertEq(loanToken.balanceOf(user), 0, "User's loan balance");
        assertEq(collateralToken.balanceOf(user), 0, "User's collateral balance");
        assertEq(
            loanToken.balanceOf(address(morpho)),
            vars.expectedTotalSupply - vars.expectedTotalBorrow,
            "User's loan balance"
        );
        assertEq(collateralToken.balanceOf(address(morpho)), vars.expectedCollateral, "Morpho's collateral balance");
        assertEq(
            loanToken.balanceOf(address(genericModule1)), vars.expectedModuleLoanBalance, unicode"Module's loan balance"
        );
        assertEq(
            collateralToken.balanceOf(address(genericModule1)),
            vars.expectedModuleCollateralBalance,
            "Module's collateral balance"
        );
    }

    function _addSupplyData(BundleTransactionsVars memory vars, uint256 amount, address user) internal {
        amount = bound(amount % MAX_AMOUNT, MIN_AMOUNT, MAX_AMOUNT);

        _transferMissingLoan(vars, amount);

        bundle.push(_morphoSupply(marketParams, amount, 0, 0, user));
        vars.expectedModuleLoanBalance -= amount;

        uint256 expectedAddedSupplyShares = amount.toSharesDown(vars.expectedTotalSupply, vars.expectedSupplyShares);
        vars.expectedTotalSupply += amount;
        vars.expectedSupplyShares += expectedAddedSupplyShares;
    }

    function _addSupplyCollateralData(BundleTransactionsVars memory vars, uint256 amount, address user) internal {
        amount = bound(amount % MAX_AMOUNT, MIN_AMOUNT, MAX_AMOUNT);

        _transferMissingCollateral(vars, amount);

        bundle.push(_morphoSupplyCollateral(marketParams, amount, user));
        vars.expectedModuleCollateralBalance -= amount;

        vars.expectedCollateral += amount;
    }

    function _addWithdrawData(BundleTransactionsVars memory vars, uint256 amount) internal {
        uint256 availableLiquidity = vars.expectedTotalSupply - vars.expectedTotalBorrow;
        if (availableLiquidity == 0 || vars.expectedSupplyShares == 0) return;

        uint256 supplyBalance =
            vars.expectedSupplyShares.toAssetsDown(vars.expectedTotalSupply, vars.expectedSupplyShares);

        uint256 maxAmount = UtilsLib.min(supplyBalance, availableLiquidity);
        amount = bound(amount % maxAmount, 1, maxAmount);

        bundle.push(_morphoWithdraw(marketParams, amount, 0, type(uint256).max, address(genericModule1)));
        vars.expectedModuleLoanBalance += amount;

        uint256 expectedDecreasedSupplyShares = amount.toSharesUp(vars.expectedTotalSupply, vars.expectedSupplyShares);
        vars.expectedTotalSupply -= amount;
        vars.expectedSupplyShares -= expectedDecreasedSupplyShares;
    }

    function _addBorrowData(BundleTransactionsVars memory vars, uint256 shares) internal {
        uint256 availableLiquidity = vars.expectedTotalSupply - vars.expectedTotalBorrow;
        if (availableLiquidity == 0 || vars.expectedCollateral == 0) return;

        uint256 totalBorrowPower = vars.expectedCollateral.wMulDown(marketParams.lltv);

        uint256 borrowed = vars.expectedBorrowShares.toAssetsUp(vars.expectedTotalBorrow, vars.expectedBorrowShares);

        uint256 currentBorrowPower = totalBorrowPower - borrowed;
        if (currentBorrowPower == 0) return;

        uint256 maxShares = UtilsLib.min(currentBorrowPower, availableLiquidity).toSharesDown(
            vars.expectedTotalBorrow, vars.expectedBorrowShares
        );
        if (maxShares < MIN_AMOUNT) return;
        shares = bound(shares % maxShares, MIN_AMOUNT, maxShares);

        bundle.push(_morphoBorrow(marketParams, 0, shares, 0, address(genericModule1)));
        uint256 expectedBorrowedAmount = shares.toAssetsDown(vars.expectedTotalBorrow, vars.expectedBorrowShares);
        vars.expectedModuleLoanBalance += expectedBorrowedAmount;

        vars.expectedTotalBorrow += expectedBorrowedAmount;
        vars.expectedBorrowShares += shares;
    }

    function _addRepayData(BundleTransactionsVars memory vars, uint256 amount, address user) internal {
        if (vars.expectedBorrowShares == 0) return;

        uint256 borrowBalance =
            vars.expectedBorrowShares.toAssetsDown(vars.expectedTotalBorrow, vars.expectedBorrowShares);

        amount = bound(amount % borrowBalance, 1, borrowBalance);

        _transferMissingLoan(vars, amount);

        bundle.push(_morphoRepay(marketParams, amount, 0, 0, user));
        vars.expectedModuleLoanBalance -= amount;

        uint256 expectedDecreasedBorrowShares = amount.toSharesDown(vars.expectedTotalBorrow, vars.expectedBorrowShares);
        vars.expectedTotalBorrow -= amount;
        vars.expectedBorrowShares -= expectedDecreasedBorrowShares;
    }

    function _addWithdrawCollateralData(BundleTransactionsVars memory vars, uint256 amount) internal {
        if (vars.expectedCollateral == 0) return;

        uint256 borrowPower = vars.expectedCollateral.wMulDown(marketParams.lltv);
        uint256 borrowed = vars.expectedBorrowShares.toAssetsUp(vars.expectedTotalBorrow, vars.expectedBorrowShares);

        uint256 withdrawableCollateral = (borrowPower - borrowed).wDivDown(marketParams.lltv);
        if (withdrawableCollateral == 0) return;

        amount = bound(amount % withdrawableCollateral, 1, withdrawableCollateral);

        bundle.push(_morphoWithdrawCollateral(marketParams, amount, address(genericModule1)));
        vars.expectedModuleCollateralBalance += amount;

        vars.expectedCollateral -= amount;
    }

    function _transferMissingLoan(BundleTransactionsVars memory vars, uint256 amount) internal {
        if (amount > vars.expectedModuleLoanBalance) {
            uint256 missingAmount = amount - vars.expectedModuleLoanBalance;
            bundle.push(_erc20TransferFrom(address(loanToken), missingAmount));
            vars.initialUserLoanBalance += missingAmount;
            vars.expectedModuleLoanBalance += missingAmount;
        }
    }

    function _transferMissingCollateral(BundleTransactionsVars memory vars, uint256 amount) internal {
        if (amount > vars.expectedModuleCollateralBalance) {
            uint256 missingAmount = amount - vars.expectedModuleCollateralBalance;
            bundle.push(_erc20TransferFrom(address(collateralToken), missingAmount));
            vars.initialUserCollateralBalance += missingAmount;
            vars.expectedModuleCollateralBalance += missingAmount;
        }
    }

    function testFlashLoan(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        loanToken.setBalance(address(this), amount);

        morpho.supply(marketParams, amount, 0, SUPPLIER, hex"");

        callbackBundle.push(_erc20Transfer(address(loanToken), USER, amount, genericModule1));
        callbackBundle.push(_erc20TransferFrom(address(loanToken), amount));

        bundle.push(_morphoFlashLoan(address(loanToken), amount));

        vm.prank(USER);
        bundler.multicall(bundle, _hashBundles(callbackBundle));

        assertEq(loanToken.balanceOf(USER), 0, "User's loan token balance");
        assertEq(loanToken.balanceOf(address(genericModule1)), 0, "Module's loan token balance");
        assertEq(loanToken.balanceOf(address(morpho)), amount, "Morpho's loan token balance");
    }

    function testReallocateTo(uint256 amount, uint256 maxIn, uint256 maxOut, uint256 fee) public {
        IPublicAllocator publicAllocator = IPublicAllocator(deployCode("PublicAllocator.sol", abi.encode(morpho)));
        vm.label(address(publicAllocator), "PublicAllocator");

        amount = bound(amount, 1, type(uint64).max);
        fee = bound(fee, 1, 1 ether);
        maxIn = bound(maxIn, amount, MAX_SETTABLE_FLOW_CAP);
        maxOut = bound(maxOut, amount, MAX_SETTABLE_FLOW_CAP);

        FlowCapsConfig[] memory flows = new FlowCapsConfig[](2);
        flows[0].id = marketParams.id();
        flows[0].caps.maxIn = uint128(maxIn);
        flows[1].id = idleMarketParams.id();
        flows[1].caps.maxOut = uint128(maxOut);

        vm.startPrank(VAULT_OWNER);
        vault.setIsAllocator(address(publicAllocator), true);
        publicAllocator.setFee(address(vault), fee);
        publicAllocator.setFlowCaps(address(vault), flows);
        vm.stopPrank();

        loanToken.setBalance(SUPPLIER, amount);
        vm.prank(SUPPLIER);
        vault.deposit(amount, SUPPLIER);

        Withdrawal[] memory withdrawals = new Withdrawal[](1);
        withdrawals[0].marketParams = idleMarketParams;
        withdrawals[0].amount = uint128(amount);
        bundle.push(_reallocateTo(address(publicAllocator), address(vault), fee, withdrawals, marketParams));

        assertEq(morpho.expectedSupplyAssets(idleMarketParams, address(vault)), amount, "initial idle");
        assertEq(morpho.expectedSupplyAssets(marketParams, address(vault)), 0, "initial market");

        vm.deal(USER, fee);
        vm.prank(USER);
        bundler.multicall{value: fee}(bundle, new bytes32[](0));

        assertEq(morpho.expectedSupplyAssets(idleMarketParams, address(vault)), 0, "final idle");
        assertEq(morpho.expectedSupplyAssets(marketParams, address(vault)), amount, "final market");
    }
}
