// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IERC20Permit} from "../../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IAaveV3} from "../../../src/interfaces/IAaveV3.sol";

import {SigUtils, Permit} from "../../helpers/SigUtils.sol";
import "../../../src/adapters/migration/AaveV3MigrationAdapter.sol";

import "./helpers/MigrationForkTest.sol";

contract AaveV3MigrationAdapterForkTest is MigrationForkTest {
    using SafeERC20 for IERC20;
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;

    address internal immutable AAVE_V3_POOL = getAddress("AAVE_V3_POOL");
    address internal immutable CB_ETH = getAddress("CB_ETH");
    address internal immutable WETH = getAddress("WETH");
    address internal immutable WST_ETH = getAddress("WST_ETH");
    address internal immutable USDT = getAddress("USDT");

    uint256 internal constant RATE_MODE = 2;

    uint256 internal collateralSupplied;
    uint256 internal constant borrowed = 1 ether;

    AaveV3MigrationAdapter internal migrationAdapter;

    function setUp() public override {
        super.setUp();

        if (block.chainid == 1) {
            _initMarket(WST_ETH, WETH);
            collateralSupplied = 10_000 ether;
        }
        if (block.chainid == 8453) {
            _initMarket(CB_ETH, WETH);
            // To avoid getting above the Aave supply cap.
            collateralSupplied = 2 ether;
        }

        vm.label(AAVE_V3_POOL, "Aave V3 Pool");

        migrationAdapter = new AaveV3MigrationAdapter(address(bundler3), address(AAVE_V3_POOL));
        vm.label(address(migrationAdapter), "Aave V3 Migration Adapter");
    }

    function testAaveV3RepayUnauthorized(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(ErrorsLib.UnauthorizedSender.selector);
        migrationAdapter.aaveV3Repay(marketParams.loanToken, amount, 1, address(this));
    }

    function testAaveV3WithdrawUnauthorized(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(ErrorsLib.UnauthorizedSender.selector);
        migrationAdapter.aaveV3Withdraw(marketParams.loanToken, amount, address(this));
    }

    function testAaveV3RepayZeroAmount() public {
        bundle.push(_aaveV3Repay(marketParams.loanToken, 0, address(this)));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        bundler3.multicall(bundle);
    }

    function testAaveV3RepayOnBehalf() public {
        deal(marketParams.collateralToken, USER, collateralSupplied);

        vm.startPrank(USER);
        IERC20(marketParams.collateralToken).forceApprove(AAVE_V3_POOL, collateralSupplied);
        IAaveV3(AAVE_V3_POOL).supply(marketParams.collateralToken, collateralSupplied, USER, 0);
        IAaveV3(AAVE_V3_POOL).borrow(marketParams.loanToken, borrowed, RATE_MODE, 0, USER);
        vm.stopPrank();

        (, uint256 debt,,,,) = IAaveV3(AAVE_V3_POOL).getUserAccountData(USER);
        assertGt(debt, 0);

        deal(marketParams.loanToken, address(migrationAdapter), borrowed);
        bundle.push(_aaveV3Repay(marketParams.loanToken, borrowed, USER));
        bundler3.multicall(bundle);

        (, debt,,,,) = IAaveV3(AAVE_V3_POOL).getUserAccountData(USER);
        assertEq(debt, 0);

        assertEq(
            IERC20(marketParams.loanToken).allowance(address(migrationAdapter), address(AAVE_V3_POOL)),
            0,
            "loanToken.allowance(migrationAdapter, AaveV3Pool)"
        );
    }

    function testMigrateBorrowerWithATokenPermit() public {
        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);

        _provideLiquidity(borrowed);

        deal(marketParams.collateralToken, user, collateralSupplied);

        vm.startPrank(user);
        IERC20(marketParams.collateralToken).forceApprove(AAVE_V3_POOL, collateralSupplied);
        IAaveV3(AAVE_V3_POOL).supply(marketParams.collateralToken, collateralSupplied, user, 0);
        IAaveV3(AAVE_V3_POOL).borrow(marketParams.loanToken, borrowed, RATE_MODE, 0, user);
        vm.stopPrank();

        address aToken = _getATokenV3(marketParams.collateralToken);
        uint256 aTokenBalance = IERC20(aToken).balanceOf(user);

        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));
        callbackBundle.push(_morphoBorrow(marketParams, borrowed, 0, 0, address(migrationAdapter)));
        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, false, 1, false));
        callbackBundle.push(_aaveV3Repay(marketParams.loanToken, borrowed / 2, user));
        callbackBundle.push(_aaveV3Repay(marketParams.loanToken, type(uint256).max, user));
        callbackBundle.push(_aaveV3PermitAToken(aToken, privateKey, address(generalAdapter1), aTokenBalance));
        callbackBundle.push(_erc20TransferFrom(aToken, address(migrationAdapter), aTokenBalance));
        callbackBundle.push(_aaveV3Withdraw(marketParams.collateralToken, collateralSupplied, address(generalAdapter1)));

        bundle.push(_morphoSupplyCollateral(marketParams, collateralSupplied, user, abi.encode(callbackBundle)));

        vm.prank(user);
        bundler3.multicall(bundle);

        _assertBorrowerPosition(collateralSupplied, borrowed, user, address(generalAdapter1));
    }

    function testMigrateBorrowerWithPermit2() public {
        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);

        _provideLiquidity(borrowed);

        deal(marketParams.collateralToken, user, collateralSupplied);

        vm.startPrank(user);
        IERC20(marketParams.collateralToken).forceApprove(AAVE_V3_POOL, collateralSupplied);
        IAaveV3(AAVE_V3_POOL).supply(marketParams.collateralToken, collateralSupplied, user, 0);
        IAaveV3(AAVE_V3_POOL).borrow(marketParams.loanToken, borrowed, RATE_MODE, 0, user);
        vm.stopPrank();

        address aToken = _getATokenV3(marketParams.collateralToken);
        uint256 aTokenBalance = IERC20(aToken).balanceOf(user);

        vm.prank(user);
        IERC20(aToken).forceApprove(address(Permit2Lib.PERMIT2), aTokenBalance);

        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));
        callbackBundle.push(_morphoBorrow(marketParams, borrowed, 0, 0, address(migrationAdapter)));
        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, false, 1, false));
        callbackBundle.push(_aaveV3Repay(marketParams.loanToken, borrowed / 2, user));
        callbackBundle.push(_aaveV3Repay(marketParams.loanToken, type(uint256).max, user));
        callbackBundle.push(_approve2(privateKey, aToken, uint160(aTokenBalance), 0, false));
        callbackBundle.push(_permit2TransferFrom(aToken, address(migrationAdapter), aTokenBalance));
        callbackBundle.push(_aaveV3Withdraw(marketParams.collateralToken, collateralSupplied, address(generalAdapter1)));

        bundle.push(_morphoSupplyCollateral(marketParams, collateralSupplied, user, abi.encode(callbackBundle)));

        vm.prank(user);
        bundler3.multicall(bundle);

        _assertBorrowerPosition(collateralSupplied, borrowed, user, address(generalAdapter1));
    }

    function testMigrateUSDTPositionWithPermit2() public onlyEthereum {
        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);

        uint256 amountUsdt = collateralSupplied / 1e10;

        _initMarket(USDT, WETH);
        _provideLiquidity(borrowed);

        oracle.setPrice(1e46);
        deal(USDT, user, amountUsdt);

        vm.startPrank(user);
        IERC20(USDT).forceApprove(AAVE_V3_POOL, amountUsdt);
        IAaveV3(AAVE_V3_POOL).supply(USDT, amountUsdt, user, 0);
        IAaveV3(AAVE_V3_POOL).borrow(marketParams.loanToken, borrowed, RATE_MODE, 0, user);
        vm.stopPrank();

        address aToken = _getATokenV3(USDT);
        uint256 aTokenBalance = IERC20(aToken).balanceOf(user);

        vm.prank(user);
        IERC20(aToken).forceApprove(address(Permit2Lib.PERMIT2), aTokenBalance);

        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));
        callbackBundle.push(_morphoBorrow(marketParams, borrowed, 0, 0, address(migrationAdapter)));
        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, false, 1, false));
        callbackBundle.push(_aaveV3Repay(marketParams.loanToken, borrowed / 2, user));
        callbackBundle.push(_aaveV3Repay(marketParams.loanToken, type(uint256).max, user));
        callbackBundle.push(_approve2(privateKey, aToken, uint160(aTokenBalance), 0, false));
        callbackBundle.push(_permit2TransferFrom(aToken, address(migrationAdapter), aTokenBalance));
        callbackBundle.push(_aaveV3Withdraw(USDT, amountUsdt, address(generalAdapter1)));

        bundle.push(_morphoSupplyCollateral(marketParams, amountUsdt, user, abi.encode(callbackBundle)));

        vm.prank(user);
        bundler3.multicall(bundle);

        _assertBorrowerPosition(amountUsdt, borrowed, user, address(generalAdapter1));
    }

    function testMigrateSupplierWithATokenPermit(uint256 supplied) public {
        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);
        supplied = bound(supplied, 100, 100 ether);

        deal(marketParams.loanToken, user, supplied + 1);

        vm.startPrank(user);
        IERC20(marketParams.loanToken).forceApprove(AAVE_V3_POOL, supplied + 1);
        IAaveV3(AAVE_V3_POOL).supply(marketParams.loanToken, supplied + 1, user, 0);
        vm.stopPrank();

        address aToken = _getATokenV3(marketParams.loanToken);
        uint256 aTokenBalance = IERC20(aToken).balanceOf(user);

        bundle.push(_aaveV3PermitAToken(aToken, privateKey, address(generalAdapter1), aTokenBalance));
        bundle.push(_erc20TransferFrom(aToken, address(migrationAdapter), aTokenBalance));
        bundle.push(_aaveV3Withdraw(marketParams.loanToken, supplied, address(generalAdapter1)));
        bundle.push(_morphoSupply(marketParams, supplied, 0, type(uint256).max, user, hex""));

        vm.prank(user);
        bundler3.multicall(bundle);

        _assertSupplierPosition(supplied, user, address(generalAdapter1));
    }

    function testMigrateSupplierWithPermit2(uint256 supplied) public {
        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);
        supplied = bound(supplied, 100, 100 ether);

        deal(marketParams.loanToken, user, supplied + 1);

        vm.startPrank(user);
        IERC20(marketParams.loanToken).forceApprove(AAVE_V3_POOL, supplied + 1);
        IAaveV3(AAVE_V3_POOL).supply(marketParams.loanToken, supplied + 1, user, 0);
        vm.stopPrank();

        address aToken = _getATokenV3(marketParams.loanToken);
        uint256 aTokenBalance = IERC20(aToken).balanceOf(user);

        vm.prank(user);
        IERC20(aToken).forceApprove(address(Permit2Lib.PERMIT2), aTokenBalance);

        bundle.push(_approve2(privateKey, aToken, uint160(aTokenBalance), 0, false));
        bundle.push(_permit2TransferFrom(aToken, address(migrationAdapter), aTokenBalance));
        bundle.push(_aaveV3Withdraw(marketParams.loanToken, supplied, address(generalAdapter1)));
        bundle.push(_morphoSupply(marketParams, supplied, 0, type(uint256).max, user, hex""));

        vm.prank(user);
        bundler3.multicall(bundle);

        _assertSupplierPosition(supplied, user, address(generalAdapter1));
    }

    function testMigrateSupplierToVaultWithATokenPermit(uint256 supplied) public {
        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);
        supplied = bound(supplied, 100, 100 ether);

        deal(marketParams.loanToken, user, supplied + 1);

        vm.startPrank(user);
        IERC20(marketParams.loanToken).forceApprove(AAVE_V3_POOL, supplied + 1);
        IAaveV3(AAVE_V3_POOL).supply(marketParams.loanToken, supplied + 1, user, 0);
        vm.stopPrank();

        address aToken = _getATokenV3(marketParams.loanToken);
        uint256 aTokenBalance = IERC20(aToken).balanceOf(user);

        bundle.push(_aaveV3PermitAToken(aToken, privateKey, address(generalAdapter1), aTokenBalance));
        bundle.push(_erc20TransferFrom(aToken, address(migrationAdapter), aTokenBalance));
        bundle.push(_aaveV3Withdraw(marketParams.loanToken, supplied, address(generalAdapter1)));
        bundle.push(_erc4626Deposit(address(suppliersVault), supplied, type(uint256).max, user));

        vm.prank(user);
        bundler3.multicall(bundle);

        _assertVaultSupplierPosition(supplied, user, address(generalAdapter1));
    }

    function testMigrateSupplierToVaultWithPermit2(uint256 supplied) public {
        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);
        supplied = bound(supplied, 100, 100 ether);

        deal(marketParams.loanToken, user, supplied + 1);

        vm.startPrank(user);
        IERC20(marketParams.loanToken).forceApprove(AAVE_V3_POOL, supplied + 1);
        IAaveV3(AAVE_V3_POOL).supply(marketParams.loanToken, supplied + 1, user, 0);
        vm.stopPrank();

        address aToken = _getATokenV3(marketParams.loanToken);
        uint256 aTokenBalance = IERC20(aToken).balanceOf(user);

        vm.prank(user);
        IERC20(aToken).forceApprove(address(Permit2Lib.PERMIT2), aTokenBalance);

        bundle.push(_approve2(privateKey, aToken, uint160(aTokenBalance), 0, false));
        bundle.push(_permit2TransferFrom(aToken, address(migrationAdapter), aTokenBalance));
        bundle.push(_aaveV3Withdraw(marketParams.loanToken, supplied, address(generalAdapter1)));
        bundle.push(_erc4626Deposit(address(suppliersVault), supplied, type(uint256).max, user));

        vm.prank(user);
        bundler3.multicall(bundle);

        _assertVaultSupplierPosition(supplied, user, address(generalAdapter1));
    }

    function _getATokenV3(address asset) internal view returns (address) {
        return IAaveV3(AAVE_V3_POOL).getReserveData(asset).aTokenAddress;
    }

    /* ACTIONS */

    function _aaveV3PermitAToken(address aToken, uint256 privateKey, address adapter, uint256 amount)
        internal
        view
        returns (Call memory)
    {
        address user = vm.addr(privateKey);
        uint256 nonce = IERC20Permit(aToken).nonces(user);

        Permit memory permit = Permit(user, adapter, amount, nonce, SIGNATURE_DEADLINE);
        bytes32 hashed = SigUtils.toTypedDataHash(IERC20Permit(aToken).DOMAIN_SEPARATOR(), permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, hashed);

        bytes memory callData =
            abi.encodeCall(IERC20Permit.permit, (user, adapter, amount, SIGNATURE_DEADLINE, v, r, s));

        return _call(aToken, callData, 0, false);
    }

    function _aaveV3Repay(address asset, uint256 amount, address onBehalf) internal view returns (Call memory) {
        return _call(
            migrationAdapter, abi.encodeCall(AaveV3MigrationAdapter.aaveV3Repay, (asset, amount, RATE_MODE, onBehalf))
        );
    }

    function _aaveV3Withdraw(address asset, uint256 amount, address receiver) internal view returns (Call memory) {
        return _call(migrationAdapter, abi.encodeCall(AaveV3MigrationAdapter.aaveV3Withdraw, (asset, amount, receiver)));
    }
}
