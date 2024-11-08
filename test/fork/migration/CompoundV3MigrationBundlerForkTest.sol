// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {CompoundV3Authorization} from "../../helpers/SigUtils.sol";

import "../../../src/migration/CompoundV3MigrationBundlerV2.sol";

import "./helpers/MigrationForkTest.sol";

contract CompoundV3MigrationBundlerForkTest is MigrationForkTest {
    using SafeTransferLib for ERC20;
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;
    using HubLib for Hub;

    uint256 collateralSupplied = 10 ether;
    uint256 borrowed = 1 ether;

    CompoundV3MigrationBundlerV2 public migrationBundler;

    function setUp() public override {
        super.setUp();

        _initMarket(CB_ETH, WETH);

        migrationBundler = new CompoundV3MigrationBundlerV2(address(hub));
    }

    function testCompoundV3RepayUnauthorized(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectPartialRevert(ErrorsLib.UnauthorizedSender.selector);
        migrationBundler.compoundV3Repay(C_WETH_V3, amount);
    }

    function testCompoundV3RepayZeroAmount() public {
        bundle.push(_compoundV3Repay(C_WETH_V3, 0));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        hub.multicall(bundle);
    }

    function testCompoundV3AllowBySigUnauthorized(uint256 privateKey) public {
        privateKey = boundPrivateKey(privateKey);

        vm.expectPartialRevert(ErrorsLib.UnauthorizedSender.selector);
        migrationBundler.compoundV3AllowBySig(C_WETH_V3, true, 0, SIGNATURE_DEADLINE, 0, 0, 0, false);
    }

    function testCompoundVAuthorizationWithSigRevert(uint256 privateKey, address owner) public {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);

        vm.assume(owner != user);

        bytes32 digest = SigUtils.toTypedDataHash(
            C_WETH_V3, CompoundV3Authorization(owner, address(migrationBundler), true, 0, SIGNATURE_DEADLINE)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        bundle.push(
            _call(
                migrationBundler,
                abi.encodeCall(
                    migrationBundler.compoundV3AllowBySig, (C_WETH_V3, true, 0, SIGNATURE_DEADLINE, v, r, s, false)
                )
            )
        );

        vm.prank(user);
        vm.expectRevert(ICompoundV3.BadSignatory.selector);
        hub.multicall(bundle);
    }

    function testMigrateBorrowerWithCompoundAllowance(uint256 privateKey) public {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);

        _provideLiquidity(borrowed);

        deal(marketParams.collateralToken, user, collateralSupplied);

        vm.startPrank(user);
        ERC20(marketParams.collateralToken).safeApprove(C_WETH_V3, collateralSupplied);
        ICompoundV3(C_WETH_V3).supply(marketParams.collateralToken, collateralSupplied);
        ICompoundV3(C_WETH_V3).withdraw(marketParams.loanToken, borrowed);
        vm.stopPrank();

        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));
        callbackBundle.push(_morphoBorrow(marketParams, borrowed, 0, type(uint256).max, address(migrationBundler)));
        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, false, 1, false));
        callbackBundle.push(_compoundV3Repay(C_WETH_V3, borrowed / 2));
        callbackBundle.push(_compoundV3Repay(C_WETH_V3, type(uint256).max));
        callbackBundle.push(_compoundV3Allow(privateKey, C_WETH_V3, address(migrationBundler), true, 0, false));
        callbackBundle.push(
            _compoundV3WithdrawFrom(
                C_WETH_V3, marketParams.collateralToken, collateralSupplied, address(genericBundler1)
            )
        );
        callbackBundle.push(_compoundV3Allow(privateKey, C_WETH_V3, address(migrationBundler), false, 1, false));

        bundle.push(_morphoSupplyCollateral(marketParams, collateralSupplied, user));

        vm.prank(user);
        hub.multicall(bundle, _hashBundles(callbackBundle));

        _assertBorrowerPosition(collateralSupplied, borrowed, user, address(genericBundler1));
    }

    function testMigrateSupplierWithCompoundAllowance(uint256 privateKey, uint256 supplied) public {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);
        supplied = bound(supplied, 101, 100 ether);

        deal(marketParams.loanToken, user, supplied);

        vm.startPrank(user);
        ERC20(marketParams.loanToken).safeApprove(C_WETH_V3, supplied);
        ICompoundV3(C_WETH_V3).supply(marketParams.loanToken, supplied);
        vm.stopPrank();

        // Margin necessary due to CompoundV3 roundings.
        supplied -= 100;

        bundle.push(_compoundV3Allow(privateKey, C_WETH_V3, address(migrationBundler), true, 0, false));
        bundle.push(_compoundV3WithdrawFrom(C_WETH_V3, marketParams.loanToken, supplied, address(genericBundler1)));
        bundle.push(_compoundV3Allow(privateKey, C_WETH_V3, address(migrationBundler), false, 1, false));
        bundle.push(_morphoSupply(marketParams, supplied, 0, 0, user));

        vm.prank(user);
        hub.multicall(bundle);

        _assertSupplierPosition(supplied, user, address(genericBundler1));
    }

    function testMigrateSupplierToVaultWithCompoundAllowance(uint256 privateKey, uint256 supplied) public {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);
        supplied = bound(supplied, 101, 100 ether);

        deal(marketParams.loanToken, user, supplied);

        vm.startPrank(user);
        ERC20(marketParams.loanToken).safeApprove(C_WETH_V3, supplied);
        ICompoundV3(C_WETH_V3).supply(marketParams.loanToken, supplied);
        vm.stopPrank();

        // Margin necessary due to CompoundV3 roundings.
        supplied -= 100;

        bundle.push(_compoundV3Allow(privateKey, C_WETH_V3, address(migrationBundler), true, 0, false));
        bundle.push(_compoundV3WithdrawFrom(C_WETH_V3, marketParams.loanToken, supplied, address(genericBundler1)));
        bundle.push(_compoundV3Allow(privateKey, C_WETH_V3, address(migrationBundler), false, 1, false));
        bundle.push(_erc4626Deposit(address(suppliersVault), supplied, 0, user));

        vm.prank(user);
        hub.multicall(bundle);

        _assertVaultSupplierPosition(supplied, user, address(genericBundler1));
    }

    function testCompoundV3AllowUnauthorized() public {
        vm.expectPartialRevert(ErrorsLib.UnauthorizedSender.selector);
        migrationBundler.compoundV3AllowBySig(C_WETH_V3, true, 0, SIGNATURE_DEADLINE, 0, 0, 0, false);
    }

    function testCompoundV3WithdrawFromUnauthorized(uint256 amount, address receiver) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectPartialRevert(ErrorsLib.UnauthorizedSender.selector);
        migrationBundler.compoundV3WithdrawFrom(C_WETH_V3, marketParams.loanToken, amount, receiver);
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
            migrationBundler,
            abi.encodeCall(
                migrationBundler.compoundV3AllowBySig,
                (instance, isAllowed, nonce, SIGNATURE_DEADLINE, v, r, s, skipRevert)
            )
        );
    }

    function _compoundV3Repay(address instance, uint256 amount) internal view returns (Call memory) {
        return _call(migrationBundler, abi.encodeCall(migrationBundler.compoundV3Repay, (instance, amount)));
    }

    function _compoundV3WithdrawFrom(address instance, address asset, uint256 amount, address receiver)
        internal
        view
        returns (Call memory)
    {
        return _call(
            migrationBundler,
            abi.encodeCall(CompoundV3MigrationBundlerV2.compoundV3WithdrawFrom, (instance, asset, amount, receiver))
        );
    }
}
