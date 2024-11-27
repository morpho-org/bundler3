// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {CompoundV3Authorization} from "../../helpers/SigUtils.sol";

import "../../../src/migration/CompoundV3MigrationModule.sol";

import "./helpers/MigrationForkTest.sol";

contract CompoundV3MigrationModuleForkTest is MigrationForkTest {
    using SafeTransferLib for ERC20;
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;
    using MathLib for uint256;

    address internal C_WETH_V3 = getAddress("C_WETH_V3");
    address internal CB_ETH = getAddress("CB_ETH");
    address internal WETH = getAddress("WETH");

    uint256 collateralSupplied = 10 ether;
    uint256 borrowed = 1 ether;

    CompoundV3MigrationModule public migrationModule;

    function setUp() public override {
        super.setUp();

        _initMarket(CB_ETH, WETH);

        migrationModule = new CompoundV3MigrationModule(address(bundler));
    }

    function testCompoundV3RepayUnauthorized(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(ErrorsLib.UnauthorizedSender.selector);
        migrationModule.compoundV3Repay(C_WETH_V3, amount);
    }

    function testCompoundV3RepayZeroAmount() public {
        bundle.push(_compoundV3Repay(C_WETH_V3, 0));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        bundler.multicall(bundle);
    }

    function testCompoundV3AllowBySigUnauthorized() public {
        vm.expectRevert(ErrorsLib.UnauthorizedSender.selector);
        migrationModule.compoundV3AllowBySig(C_WETH_V3, true, 0, SIGNATURE_DEADLINE, 0, 0, 0, false);
    }

    function testCompoundV3AuthorizationWithSigRevert(address owner) public {
        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);

        vm.assume(owner != user);

        bytes32 digest = SigUtils.toTypedDataHash(
            C_WETH_V3, CompoundV3Authorization(owner, address(migrationModule), true, 0, SIGNATURE_DEADLINE)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        bundle.push(
            _call(
                migrationModule,
                abi.encodeCall(
                    migrationModule.compoundV3AllowBySig, (C_WETH_V3, true, 0, SIGNATURE_DEADLINE, v, r, s, false)
                )
            )
        );

        vm.prank(user);
        vm.expectRevert(ICompoundV3.BadSignatory.selector);
        bundler.multicall(bundle);
    }

    function testMigrateBorrowerWithCompoundAllowance() public {
        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);

        _provideLiquidity(borrowed);

        deal(marketParams.collateralToken, user, collateralSupplied);

        vm.startPrank(user);
        ERC20(marketParams.collateralToken).safeApprove(C_WETH_V3, collateralSupplied);
        ICompoundV3(C_WETH_V3).supply(marketParams.collateralToken, collateralSupplied);
        ICompoundV3(C_WETH_V3).withdraw(marketParams.loanToken, borrowed);
        vm.stopPrank();

        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));
        callbackBundle.push(_morphoBorrow(marketParams, borrowed, 0, type(uint256).max, address(migrationModule)));
        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, false, 1, false));
        callbackBundle.push(_compoundV3Repay(C_WETH_V3, borrowed / 2));
        callbackBundle.push(_compoundV3Repay(C_WETH_V3, type(uint256).max));
        callbackBundle.push(_compoundV3Allow(privateKey, C_WETH_V3, address(migrationModule), true, 0, false));
        callbackBundle.push(
            _compoundV3WithdrawFrom(
                C_WETH_V3, marketParams.collateralToken, collateralSupplied, address(genericModule1)
            )
        );
        callbackBundle.push(_compoundV3Allow(privateKey, C_WETH_V3, address(migrationModule), false, 1, false));

        bundle.push(_morphoSupplyCollateral(marketParams, collateralSupplied, user, abi.encode(callbackBundle)));

        vm.prank(user);
        bundler.multicall(bundle);

        _assertBorrowerPosition(collateralSupplied, borrowed, user, address(genericModule1));
    }

    function testCompoundV3RepayMax(uint256 fractionRepaid) public {
        fractionRepaid = bound(fractionRepaid, 0.01 ether, 0.99 ether);

        deal(CB_ETH, address(this), collateralSupplied);

        ERC20(CB_ETH).safeApprove(C_WETH_V3, collateralSupplied);
        ICompoundV3(C_WETH_V3).supply(CB_ETH, collateralSupplied);
        ICompoundV3(C_WETH_V3).withdraw(WETH, borrowed);

        uint256 repaid = borrowed.wMulDown(fractionRepaid);
        ERC20(WETH).safeTransfer(address(migrationModule), repaid);
        bundle.push(_compoundV3Repay(C_WETH_V3, type(uint256).max));
        bundler.multicall(bundle);

        assertApproxEqAbs(ICompoundV3(C_WETH_V3).borrowBalanceOf(address(this)), borrowed - repaid, 1);
    }

    function testCompoundV3RepayNotMax(uint256 repayFactor) public {
        repayFactor = bound(repayFactor, 0.1 ether, 10 ether);
        deal(CB_ETH, address(this), collateralSupplied);

        ERC20(CB_ETH).safeApprove(C_WETH_V3, collateralSupplied);
        ICompoundV3(C_WETH_V3).supply(CB_ETH, collateralSupplied);
        ICompoundV3(C_WETH_V3).withdraw(WETH, borrowed);

        uint256 toRepay = borrowed.wMulDown(repayFactor);
        deal(WETH, address(this), toRepay);
        ERC20(WETH).safeTransfer(address(migrationModule), toRepay);
        bundle.push(_compoundV3Repay(C_WETH_V3, toRepay));
        bundler.multicall(bundle);

        if (repayFactor < 1 ether) {
            assertApproxEqAbs(ICompoundV3(C_WETH_V3).borrowBalanceOf(address(this)), borrowed - toRepay, 1);
        } else {
            assertEq(ICompoundV3(C_WETH_V3).borrowBalanceOf(address(this)), 0);
        }
    }

    function testCompoundV3WithdrawNotMax(uint256 supplied, uint256 withdrawFactor) public {
        supplied = bound(supplied, 1 ether, 100 ether);
        withdrawFactor = bound(withdrawFactor, 0.1 ether, 10 ether);
        uint256 toWithdraw = supplied.wMulDown(withdrawFactor);

        deal(marketParams.loanToken, address(this), supplied);

        ERC20(WETH).safeApprove(C_WETH_V3, supplied);
        ICompoundV3(C_WETH_V3).supply(WETH, supplied);
        ICompoundV3(C_WETH_V3).allow(address(migrationModule), true);

        bundle.push(_compoundV3WithdrawFrom(C_WETH_V3, WETH, toWithdraw, address(genericModule1)));
        bundler.multicall(bundle);

        if (withdrawFactor < 1 ether) {
            assertApproxEqAbs(ERC20(WETH).balanceOf(address(genericModule1)), toWithdraw, 10);
        } else {
            assertApproxEqAbs(ERC20(WETH).balanceOf(address(genericModule1)), supplied, 10);
        }
    }

    function testMigrateSupplierWithCompoundAllowance(uint256 supplied) public {
        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);
        supplied = bound(supplied, 101, 100 ether);

        deal(marketParams.loanToken, user, supplied);

        vm.startPrank(user);
        ERC20(marketParams.loanToken).safeApprove(C_WETH_V3, supplied);
        ICompoundV3(C_WETH_V3).supply(marketParams.loanToken, supplied);
        vm.stopPrank();

        // Margin necessary due to CompoundV3 roundings.
        supplied -= 100;

        bundle.push(_compoundV3Allow(privateKey, C_WETH_V3, address(migrationModule), true, 0, false));
        bundle.push(_compoundV3WithdrawFrom(C_WETH_V3, marketParams.loanToken, supplied, address(genericModule1)));
        bundle.push(_compoundV3Allow(privateKey, C_WETH_V3, address(migrationModule), false, 1, false));
        bundle.push(_morphoSupply(marketParams, supplied, 0, 0, user, hex""));

        vm.prank(user);
        bundler.multicall(bundle);

        _assertSupplierPosition(supplied, user, address(genericModule1));
    }

    function testMigrateSupplierToVaultWithCompoundAllowance(uint256 supplied) public {
        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);
        supplied = bound(supplied, 101, 100 ether);

        deal(marketParams.loanToken, user, supplied);

        vm.startPrank(user);
        ERC20(marketParams.loanToken).safeApprove(C_WETH_V3, supplied);
        ICompoundV3(C_WETH_V3).supply(marketParams.loanToken, supplied);
        vm.stopPrank();

        // Margin necessary due to CompoundV3 roundings.
        supplied -= 100;

        bundle.push(_compoundV3Allow(privateKey, C_WETH_V3, address(migrationModule), true, 0, false));
        bundle.push(_compoundV3WithdrawFrom(C_WETH_V3, marketParams.loanToken, supplied, address(genericModule1)));
        bundle.push(_compoundV3Allow(privateKey, C_WETH_V3, address(migrationModule), false, 1, false));
        bundle.push(_erc4626Deposit(address(suppliersVault), supplied, type(uint256).max, user));

        vm.prank(user);
        bundler.multicall(bundle);

        _assertVaultSupplierPosition(supplied, user, address(genericModule1));
    }

    function testCompoundV3AllowUnauthorized() public {
        vm.expectRevert(ErrorsLib.UnauthorizedSender.selector);
        migrationModule.compoundV3AllowBySig(C_WETH_V3, true, 0, SIGNATURE_DEADLINE, 0, 0, 0, false);
    }

    function testCompoundV3WithdrawFromUnauthorized(uint256 amount, address receiver) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(ErrorsLib.UnauthorizedSender.selector);
        migrationModule.compoundV3WithdrawFrom(C_WETH_V3, marketParams.loanToken, amount, receiver);
    }

    /* ACTIONS */

    function _compoundV3Allow(
        uint256 privateKey,
        address instance,
        address manager,
        bool isAllowed,
        uint256 nonce,
        bool skipRevert
    ) internal view returns (Call memory) {
        bytes32 digest = SigUtils.toTypedDataHash(
            instance, CompoundV3Authorization(vm.addr(privateKey), manager, isAllowed, nonce, SIGNATURE_DEADLINE)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        return _call(
            migrationModule,
            abi.encodeCall(
                migrationModule.compoundV3AllowBySig,
                (instance, isAllowed, nonce, SIGNATURE_DEADLINE, v, r, s, skipRevert)
            )
        );
    }

    function _compoundV3Repay(address instance, uint256 amount) internal view returns (Call memory) {
        return _call(migrationModule, abi.encodeCall(migrationModule.compoundV3Repay, (instance, amount)));
    }

    function _compoundV3WithdrawFrom(address instance, address asset, uint256 amount, address receiver)
        internal
        view
        returns (Call memory)
    {
        return _call(
            migrationModule,
            abi.encodeCall(CompoundV3MigrationModule.compoundV3WithdrawFrom, (instance, asset, amount, receiver))
        );
    }
}
