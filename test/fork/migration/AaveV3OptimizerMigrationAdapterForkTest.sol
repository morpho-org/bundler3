// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Authorization as AaveV3OptimizerAuthorization, Signature} from "../../../src/interfaces/IAaveV3Optimizer.sol";

import "../../../src/adapters/migration/AaveV3OptimizerMigrationAdapter.sol";

import "./helpers/MigrationForkTest.sol";

interface IMorphoSettersPartial {
    function setIsSupplyCollateralPaused(address underlying, bool isPaused) external;
    function setAssetIsCollateral(address underlying, bool isCollateral) external;
}

contract AaveV3OptimizerMigrationAdapterForkTest is MigrationForkTest {
    using SafeERC20 for IERC20;
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;

    address internal immutable AAVE_V3_OPTIMIZER = getAddress("AAVE_V3_OPTIMIZER");
    address internal immutable USDT = getAddress("USDT");
    address internal immutable WST_ETH = getAddress("WST_ETH");
    address internal immutable WETH = getAddress("WETH");

    uint256 internal constant MAX_ITERATIONS = 15;

    uint256 internal constant collateralSupplied = 10_000 ether;
    uint256 internal constant borrowed = 1 ether;

    AaveV3OptimizerMigrationAdapter internal migrationAdapter;

    function setUp() public override {
        super.setUp();

        if (block.chainid != 1) return;

        _initMarket(WST_ETH, WETH);

        vm.label(AAVE_V3_OPTIMIZER, "AaveV3Optimizer");

        migrationAdapter = new AaveV3OptimizerMigrationAdapter(address(bundler3), address(AAVE_V3_OPTIMIZER));
    }

    function testAaveV3OptimizerRepayUnauthorized(uint256 amount) public onlyEthereum {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(ErrorsLib.UnauthorizedSender.selector);
        migrationAdapter.aaveV3OptimizerRepay(marketParams.loanToken, amount, address(this));
    }

    function testAaveV3Optimizer3RepayZeroAmount() public onlyEthereum {
        bundle.push(_aaveV3OptimizerRepay(marketParams.loanToken, 0, address(this)));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        bundler3.multicall(bundle);
    }

    function testAaveV3OtimizerAuthorizationWithSigRevert(address owner) public onlyEthereum {
        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);

        vm.assume(owner != user);

        bytes32 digest = SigUtils.toTypedDataHash(
            IAaveV3Optimizer(AAVE_V3_OPTIMIZER).DOMAIN_SEPARATOR(),
            AaveV3OptimizerAuthorization(owner, address(this), true, 0, SIGNATURE_DEADLINE)
        );

        Signature memory sig;
        (sig.v, sig.r, sig.s) = vm.sign(privateKey, digest);

        bundle.push(
            _call(
                AAVE_V3_OPTIMIZER,
                abi.encodeCall(
                    IAaveV3Optimizer.approveManagerWithSig, (user, address(this), true, 0, SIGNATURE_DEADLINE, sig)
                ),
                0,
                false
            )
        );

        vm.prank(user);
        vm.expectRevert(IAaveV3Optimizer.InvalidSignatory.selector);
        bundler3.multicall(bundle);
    }

    function testAaveV3OptimizerRepayOnBehalf() public onlyEthereum {
        deal(marketParams.collateralToken, USER, collateralSupplied + 1);

        vm.startPrank(USER);
        IERC20(marketParams.collateralToken).forceApprove(AAVE_V3_OPTIMIZER, collateralSupplied + 1);
        IAaveV3Optimizer(AAVE_V3_OPTIMIZER).supplyCollateral(marketParams.collateralToken, collateralSupplied + 1, USER);
        IAaveV3Optimizer(AAVE_V3_OPTIMIZER).borrow(marketParams.loanToken, borrowed, USER, USER, MAX_ITERATIONS);
        vm.stopPrank();

        uint256 debt = IAaveV3Optimizer(AAVE_V3_OPTIMIZER).borrowBalance(marketParams.loanToken, USER);
        assertGe(debt, borrowed);

        deal(marketParams.loanToken, address(migrationAdapter), borrowed);
        bundle.push(_aaveV3OptimizerRepay(marketParams.loanToken, borrowed, USER));
        bundler3.multicall(bundle);

        debt = IAaveV3Optimizer(AAVE_V3_OPTIMIZER).borrowBalance(marketParams.loanToken, USER);
        assertEq(debt, 0);

        assertEq(
            IERC20(marketParams.loanToken).allowance(address(migrationAdapter), address(AAVE_V3_OPTIMIZER)),
            0,
            "loanToken.allowance(migrationAdapter, AaveV3Optimizer)"
        );
    }

    function testMigrateBorrowerWithOptimizerPermit() public onlyEthereum {
        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);

        _provideLiquidity(borrowed);

        deal(marketParams.collateralToken, user, collateralSupplied + 1);

        vm.startPrank(user);
        IERC20(marketParams.collateralToken).forceApprove(AAVE_V3_OPTIMIZER, collateralSupplied + 1);
        IAaveV3Optimizer(AAVE_V3_OPTIMIZER).supplyCollateral(marketParams.collateralToken, collateralSupplied + 1, user);
        IAaveV3Optimizer(AAVE_V3_OPTIMIZER).borrow(marketParams.loanToken, borrowed, user, user, MAX_ITERATIONS);
        vm.stopPrank();

        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));
        callbackBundle.push(_morphoBorrow(marketParams, borrowed, 0, 0, address(migrationAdapter)));
        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, false, 1, false));
        callbackBundle.push(_aaveV3OptimizerRepay(marketParams.loanToken, borrowed / 2, user));
        callbackBundle.push(_aaveV3OptimizerRepay(marketParams.loanToken, type(uint256).max, user));
        callbackBundle.push(_aaveV3OptimizerApproveManager(privateKey, address(migrationAdapter), true, 0, false));
        callbackBundle.push(
            _aaveV3OptimizerWithdrawCollateral(
                marketParams.collateralToken, collateralSupplied, address(generalAdapter1)
            )
        );
        callbackBundle.push(_aaveV3OptimizerApproveManager(privateKey, address(migrationAdapter), false, 1, false));

        bundle.push(_morphoSupplyCollateral(marketParams, collateralSupplied, user, abi.encode(callbackBundle)));

        vm.prank(user);
        bundler3.multicall(bundle);

        _assertBorrowerPosition(collateralSupplied, borrowed, user, address(generalAdapter1));
    }

    function testMigrateUSDTBorrowerWithOptimizerPermit() public onlyEthereum {
        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);
        vm.startPrank(getAddress("MORPHO_SAFE_OWNER"));
        IMorphoSettersPartial(AAVE_V3_OPTIMIZER).setIsSupplyCollateralPaused(USDT, false);
        IMorphoSettersPartial(AAVE_V3_OPTIMIZER).setAssetIsCollateral(USDT, true);
        vm.stopPrank();

        uint256 amountUsdt = collateralSupplied / 1e10;

        _initMarket(USDT, WETH);
        oracle.setPrice(1e46);

        _provideLiquidity(borrowed);

        deal(USDT, user, amountUsdt + 1);

        vm.startPrank(user);
        IERC20(USDT).forceApprove(AAVE_V3_OPTIMIZER, amountUsdt + 1);
        IAaveV3Optimizer(AAVE_V3_OPTIMIZER).supplyCollateral(USDT, amountUsdt + 1, user);
        IAaveV3Optimizer(AAVE_V3_OPTIMIZER).borrow(marketParams.loanToken, borrowed, user, user, MAX_ITERATIONS);
        vm.stopPrank();

        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));
        callbackBundle.push(_morphoBorrow(marketParams, borrowed, 0, 0, address(migrationAdapter)));
        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, false, 1, false));
        callbackBundle.push(_aaveV3OptimizerRepay(marketParams.loanToken, borrowed / 2, user));
        callbackBundle.push(_aaveV3OptimizerRepay(marketParams.loanToken, type(uint256).max, user));
        callbackBundle.push(_aaveV3OptimizerApproveManager(privateKey, address(migrationAdapter), true, 0, false));
        callbackBundle.push(_aaveV3OptimizerWithdrawCollateral(USDT, amountUsdt, address(generalAdapter1)));
        callbackBundle.push(_aaveV3OptimizerApproveManager(privateKey, address(migrationAdapter), false, 1, false));

        bundle.push(_morphoSupplyCollateral(marketParams, amountUsdt, user, abi.encode(callbackBundle)));

        vm.prank(user);
        bundler3.multicall(bundle);

        _assertBorrowerPosition(amountUsdt, borrowed, user, address(generalAdapter1));
    }

    function testMigrateSupplierWithOptimizerPermit(uint256 supplied) public onlyEthereum {
        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);
        supplied = bound(supplied, 100, 100 ether);

        deal(marketParams.loanToken, user, supplied + 2);

        vm.startPrank(user);
        IERC20(marketParams.loanToken).forceApprove(AAVE_V3_OPTIMIZER, supplied + 2);
        IAaveV3Optimizer(AAVE_V3_OPTIMIZER).supply(marketParams.loanToken, supplied + 2, user, MAX_ITERATIONS);
        vm.stopPrank();

        bundle.push(_aaveV3OptimizerApproveManager(privateKey, address(migrationAdapter), true, 0, false));
        bundle.push(_aaveV3OptimizerWithdraw(marketParams.loanToken, supplied, address(generalAdapter1)));
        bundle.push(_aaveV3OptimizerApproveManager(privateKey, address(migrationAdapter), false, 1, false));
        bundle.push(_morphoSupply(marketParams, supplied, 0, type(uint256).max, user, hex""));

        vm.prank(user);
        bundler3.multicall(bundle);

        _assertSupplierPosition(supplied, user, address(generalAdapter1));
    }

    function testMigrateSupplierToVaultWithOptimizerPermit(uint256 supplied) public onlyEthereum {
        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);
        supplied = bound(supplied, 100, 100 ether);

        deal(marketParams.loanToken, user, supplied + 2);

        vm.startPrank(user);
        IERC20(marketParams.loanToken).forceApprove(AAVE_V3_OPTIMIZER, supplied + 2);
        IAaveV3Optimizer(AAVE_V3_OPTIMIZER).supply(marketParams.loanToken, supplied + 2, user, MAX_ITERATIONS);
        vm.stopPrank();

        bundle.push(_aaveV3OptimizerApproveManager(privateKey, address(migrationAdapter), true, 0, false));
        bundle.push(_aaveV3OptimizerWithdraw(marketParams.loanToken, supplied, address(generalAdapter1)));
        bundle.push(_aaveV3OptimizerApproveManager(privateKey, address(migrationAdapter), false, 1, false));
        bundle.push(_erc4626Deposit(address(suppliersVault), supplied, type(uint256).max, user));

        vm.prank(user);
        bundler3.multicall(bundle);

        _assertVaultSupplierPosition(supplied, user, address(generalAdapter1));
    }

    function testAaveV3OptimizerWithdrawUnauthorized(uint256 amount) public onlyEthereum {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(ErrorsLib.UnauthorizedSender.selector);
        migrationAdapter.aaveV3OptimizerWithdraw(marketParams.loanToken, amount, MAX_ITERATIONS, address(this));
    }

    function testAaveV3OptimizerWithdrawCollateralUnauthorized(uint256 amount) public onlyEthereum {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(ErrorsLib.UnauthorizedSender.selector);
        migrationAdapter.aaveV3OptimizerWithdrawCollateral(marketParams.loanToken, amount, address(this));
    }

    /* ACTIONS */

    function _aaveV3OptimizerApproveManager(
        uint256 privateKey,
        address manager,
        bool isAllowed,
        uint256 nonce,
        bool skipRevert
    ) internal view returns (Call memory) {
        address owner = vm.addr(privateKey);
        bytes32 digest = SigUtils.toTypedDataHash(
            IAaveV3Optimizer(AAVE_V3_OPTIMIZER).DOMAIN_SEPARATOR(),
            AaveV3OptimizerAuthorization(owner, manager, isAllowed, nonce, SIGNATURE_DEADLINE)
        );

        Signature memory sig;
        (sig.v, sig.r, sig.s) = vm.sign(privateKey, digest);

        return _call(
            AAVE_V3_OPTIMIZER,
            abi.encodeCall(
                IAaveV3Optimizer.approveManagerWithSig, (owner, manager, isAllowed, nonce, SIGNATURE_DEADLINE, sig)
            ),
            0,
            skipRevert
        );
    }

    function _aaveV3OptimizerRepay(address underlying, uint256 amount, address onBehalf)
        internal
        view
        returns (Call memory)
    {
        return _call(
            migrationAdapter, abi.encodeCall(migrationAdapter.aaveV3OptimizerRepay, (underlying, amount, onBehalf))
        );
    }

    function _aaveV3OptimizerWithdraw(address underlying, uint256 amount, address receiver)
        internal
        view
        returns (Call memory)
    {
        return _call(
            migrationAdapter,
            abi.encodeCall(migrationAdapter.aaveV3OptimizerWithdraw, (underlying, amount, MAX_ITERATIONS, receiver))
        );
    }

    function _aaveV3OptimizerWithdrawCollateral(address underlying, uint256 amount, address receiver)
        internal
        view
        returns (Call memory)
    {
        return _call(
            migrationAdapter,
            abi.encodeCall(migrationAdapter.aaveV3OptimizerWithdrawCollateral, (underlying, amount, receiver))
        );
    }
}
