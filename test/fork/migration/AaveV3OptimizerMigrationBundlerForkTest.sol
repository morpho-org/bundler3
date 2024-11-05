// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Authorization as AaveV3OptimizerAuthorization} from "../../../src/migration/interfaces/IAaveV3Optimizer.sol";

import "../../../src/migration/AaveV3OptimizerMigrationBundlerV2.sol";

import "./helpers/MigrationForkTest.sol";

contract AaveV3OptimizerMigrationBundlerForkTest is MigrationForkTest {
    using SafeTransferLib for ERC20;
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;

    uint256 public constant MAX_ITERATIONS = 15;

    uint256 collateralSupplied = 10_000 ether;
    uint256 borrowed = 1 ether;

    function setUp() public override {
        if (block.chainid != 1) return;

        super.setUp();

        _initMarket(DAI, WETH);

        vm.label(AAVE_V3_OPTIMIZER, "AaveV3Optimizer");

        bundler = new AaveV3OptimizerMigrationBundlerV2(address(morpho), address(AAVE_V3_OPTIMIZER));
    }

    function testAaveV3OptimizerRepayUninitiated(uint256 amount) public onlyEthereum {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(bytes(ErrorsLib.UNINITIATED));
        AaveV3OptimizerMigrationBundlerV2(address(bundler)).aaveV3OptimizerRepay(marketParams.loanToken, amount);
    }

    function testAaveV3Optimizer3RepayZeroAmount() public onlyEthereum {
        bundle.push(_aaveV3OptimizerRepay(marketParams.loanToken, 0));

        vm.expectRevert(bytes(ErrorsLib.ZERO_AMOUNT));
        bundler.multicall(bundle);
    }

    function testAaveV3OtimizerAuthorizationWithSigRevert(uint256 privateKey, address owner) public onlyEthereum {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);

        vm.assume(owner != user);

        bytes32 digest = SigUtils.toTypedDataHash(
            IAaveV3Optimizer(AAVE_V3_OPTIMIZER).DOMAIN_SEPARATOR(),
            AaveV3OptimizerAuthorization(owner, address(this), true, 0, SIGNATURE_DEADLINE)
        );

        Signature memory sig;
        (sig.v, sig.r, sig.s) = vm.sign(privateKey, digest);

        bundle.push(
            abi.encodeCall(
                AaveV3OptimizerMigrationBundlerV2.aaveV3OptimizerApproveManagerWithSig,
                (true, 0, SIGNATURE_DEADLINE, sig, false)
            )
        );

        vm.prank(user);
        vm.expectRevert(IAaveV3Optimizer.InvalidSignatory.selector);
        bundler.multicall(bundle);
    }

    function testMigrateBorrowerWithOptimizerPermit(uint256 privateKey) public onlyEthereum {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);

        _provideLiquidity(borrowed);

        deal(marketParams.collateralToken, user, collateralSupplied + 1);

        vm.startPrank(user);
        ERC20(marketParams.collateralToken).safeApprove(AAVE_V3_OPTIMIZER, collateralSupplied + 1);
        IAaveV3Optimizer(AAVE_V3_OPTIMIZER).supplyCollateral(marketParams.collateralToken, collateralSupplied + 1, user);
        IAaveV3Optimizer(AAVE_V3_OPTIMIZER).borrow(marketParams.loanToken, borrowed, user, user, MAX_ITERATIONS);
        vm.stopPrank();

        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));
        callbackBundle.push(_morphoBorrow(marketParams, borrowed, 0, type(uint256).max, address(bundler)));
        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, false, 1, false));
        callbackBundle.push(_aaveV3OptimizerRepay(marketParams.loanToken, borrowed / 2));
        callbackBundle.push(_aaveV3OptimizerRepay(marketParams.loanToken, type(uint256).max));
        callbackBundle.push(_aaveV3OptimizerApproveManager(privateKey, address(bundler), true, 0, false));
        callbackBundle.push(_aaveV3OptimizerWithdrawCollateral(marketParams.collateralToken, collateralSupplied));
        callbackBundle.push(_aaveV3OptimizerApproveManager(privateKey, address(bundler), false, 1, false));

        bundle.push(_morphoSupplyCollateral(marketParams, collateralSupplied, user));

        vm.prank(user);
        bundler.multicall(bundle);

        _assertBorrowerPosition(collateralSupplied, borrowed, user, address(bundler));
    }

    function testMigrateUSDTBorrowerWithOptimizerPermit(uint256 privateKey) public onlyEthereum {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);

        uint256 amountUsdt = collateralSupplied / 1e10;

        _initMarket(USDT, WETH);
        oracle.setPrice(1e46);

        _provideLiquidity(borrowed);

        deal(USDT, user, amountUsdt + 1);

        vm.startPrank(user);
        ERC20(USDT).safeApprove(AAVE_V3_OPTIMIZER, amountUsdt + 1);
        IAaveV3Optimizer(AAVE_V3_OPTIMIZER).supplyCollateral(USDT, amountUsdt + 1, user);
        IAaveV3Optimizer(AAVE_V3_OPTIMIZER).borrow(marketParams.loanToken, borrowed, user, user, MAX_ITERATIONS);
        vm.stopPrank();

        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));
        callbackBundle.push(_morphoBorrow(marketParams, borrowed, 0, type(uint256).max, address(bundler)));
        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, false, 1, false));
        callbackBundle.push(_aaveV3OptimizerRepay(marketParams.loanToken, borrowed / 2));
        callbackBundle.push(_aaveV3OptimizerRepay(marketParams.loanToken, type(uint256).max));
        callbackBundle.push(_aaveV3OptimizerApproveManager(privateKey, address(bundler), true, 0, false));
        callbackBundle.push(_aaveV3OptimizerWithdrawCollateral(USDT, amountUsdt));
        callbackBundle.push(_aaveV3OptimizerApproveManager(privateKey, address(bundler), false, 1, false));

        bundle.push(_morphoSupplyCollateral(marketParams, amountUsdt, user));

        vm.prank(user);
        bundler.multicall(bundle);

        _assertBorrowerPosition(amountUsdt, borrowed, user, address(bundler));
    }

    function testMigrateSupplierWithOptimizerPermit(uint256 privateKey, uint256 supplied) public onlyEthereum {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);
        supplied = bound(supplied, 100, 100 ether);

        deal(marketParams.loanToken, user, supplied + 1);

        vm.startPrank(user);
        ERC20(marketParams.loanToken).safeApprove(AAVE_V3_OPTIMIZER, supplied + 1);
        IAaveV3Optimizer(AAVE_V3_OPTIMIZER).supply(marketParams.loanToken, supplied + 1, user, MAX_ITERATIONS);
        vm.stopPrank();

        bundle.push(_aaveV3OptimizerApproveManager(privateKey, address(bundler), true, 0, false));
        bundle.push(_aaveV3OptimizerWithdraw(marketParams.loanToken, supplied));
        bundle.push(_aaveV3OptimizerApproveManager(privateKey, address(bundler), false, 1, false));
        bundle.push(_morphoSupply(marketParams, supplied, 0, 0, user));

        vm.prank(user);
        bundler.multicall(bundle);

        _assertSupplierPosition(supplied, user, address(bundler));
    }

    function testMigrateSupplierToVaultWithOptimizerPermit(uint256 privateKey, uint256 supplied) public onlyEthereum {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);
        supplied = bound(supplied, 100, 100 ether);

        deal(marketParams.loanToken, user, supplied + 1);

        vm.startPrank(user);
        ERC20(marketParams.loanToken).safeApprove(AAVE_V3_OPTIMIZER, supplied + 1);
        IAaveV3Optimizer(AAVE_V3_OPTIMIZER).supply(marketParams.loanToken, supplied + 1, user, MAX_ITERATIONS);
        vm.stopPrank();

        bundle.push(_aaveV3OptimizerApproveManager(privateKey, address(bundler), true, 0, false));
        bundle.push(_aaveV3OptimizerWithdraw(marketParams.loanToken, supplied));
        bundle.push(_aaveV3OptimizerApproveManager(privateKey, address(bundler), false, 1, false));
        bundle.push(_erc4626Deposit(address(suppliersVault), supplied, 0, user));

        vm.prank(user);
        bundler.multicall(bundle);

        _assertVaultSupplierPosition(supplied, user, address(bundler));
    }

    function testAaveV3OptimizerApproveManagerUninitiated(uint256 amount) public onlyEthereum {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        Signature memory sig;

        vm.expectRevert(bytes(ErrorsLib.UNINITIATED));
        AaveV3OptimizerMigrationBundlerV2(address(bundler)).aaveV3OptimizerApproveManagerWithSig(
            true, 0, SIGNATURE_DEADLINE, sig, false
        );
    }

    function testAaveV3OptimizerWithdrawUninitiated(uint256 amount) public onlyEthereum {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(bytes(ErrorsLib.UNINITIATED));
        AaveV3OptimizerMigrationBundlerV2(address(bundler)).aaveV3OptimizerWithdraw(
            marketParams.loanToken, amount, MAX_ITERATIONS
        );
    }

    function testAaveV3OptimizerWithdrawCollateralUninitiated(uint256 amount) public onlyEthereum {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(bytes(ErrorsLib.UNINITIATED));
        AaveV3OptimizerMigrationBundlerV2(address(bundler)).aaveV3OptimizerWithdrawCollateral(
            marketParams.loanToken, amount
        );
    }

    /* ACTIONS */

    function _aaveV3OptimizerApproveManager(
        uint256 privateKey,
        address manager,
        bool isAllowed,
        uint256 nonce,
        bool skipRevert
    ) internal view returns (bytes memory) {
        bytes32 digest = SigUtils.toTypedDataHash(
            IAaveV3Optimizer(AAVE_V3_OPTIMIZER).DOMAIN_SEPARATOR(),
            AaveV3OptimizerAuthorization(vm.addr(privateKey), manager, isAllowed, nonce, SIGNATURE_DEADLINE)
        );

        Signature memory sig;
        (sig.v, sig.r, sig.s) = vm.sign(privateKey, digest);

        return abi.encodeCall(
            AaveV3OptimizerMigrationBundlerV2.aaveV3OptimizerApproveManagerWithSig,
            (isAllowed, nonce, SIGNATURE_DEADLINE, sig, skipRevert)
        );
    }

    function _aaveV3OptimizerRepay(address underlying, uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeCall(AaveV3OptimizerMigrationBundlerV2.aaveV3OptimizerRepay, (underlying, amount));
    }

    function _aaveV3OptimizerWithdraw(address underlying, uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeCall(
            AaveV3OptimizerMigrationBundlerV2.aaveV3OptimizerWithdraw, (underlying, amount, MAX_ITERATIONS)
        );
    }

    function _aaveV3OptimizerWithdrawCollateral(address underlying, uint256 amount)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeCall(AaveV3OptimizerMigrationBundlerV2.aaveV3OptimizerWithdrawCollateral, (underlying, amount));
    }
}
