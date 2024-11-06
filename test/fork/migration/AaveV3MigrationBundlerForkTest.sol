// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IAToken} from "./interfaces/IAToken.sol";
import {IAaveV3} from "../../../../src/migration/interfaces/IAaveV3.sol";

import {SigUtils, Permit} from "../../helpers/SigUtils.sol";
import "../../../../src/migration/AaveV3MigrationBundlerV2.sol";

import "./helpers/MigrationForkTest.sol";

contract AaveV3MigrationBundlerForkTest is MigrationForkTest {
    using SafeTransferLib for ERC20;
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;

    uint256 public constant RATE_MODE = 2;

    uint256 collateralSupplied;
    uint256 borrowed = 1 ether;

    function setUp() public override {
        super.setUp();

        if (block.chainid == 1) {
            _initMarket(DAI, WETH);
            collateralSupplied = 10_000 ether;
        }
        if (block.chainid == 8453) {
            _initMarket(CB_ETH, WETH);
            // To avoid getting above the Aave supply cap.
            collateralSupplied = 2 ether;
        }

        vm.label(AAVE_V3_POOL, "Aave V3 Pool");

        bundler = new AaveV3MigrationBundlerV2(address(morpho), address(AAVE_V3_POOL));
        vm.label(address(bundler), "Aave V3 Migration Bundler");
    }

    function testAaveV3RepayUninitiated(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(bytes(ErrorsLib.UNINITIATED));
        AaveV3MigrationBundlerV2(address(bundler)).aaveV3Repay(marketParams.loanToken, amount, 1);
    }

    function testAaveV3RepayZeroAmount() public {
        bundle.push(_aaveV3Repay(marketParams.loanToken, 0));

        vm.expectRevert(bytes(ErrorsLib.ZERO_AMOUNT));
        bundler.multicall(bundle);
    }

    function testMigrateBorrowerWithATokenPermit(uint256 privateKey) public {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);

        _provideLiquidity(borrowed);

        deal(marketParams.collateralToken, user, collateralSupplied);

        vm.startPrank(user);
        ERC20(marketParams.collateralToken).safeApprove(AAVE_V3_POOL, collateralSupplied);
        IAaveV3(AAVE_V3_POOL).supply(marketParams.collateralToken, collateralSupplied, user, 0);
        IAaveV3(AAVE_V3_POOL).borrow(marketParams.loanToken, borrowed, RATE_MODE, 0, user);
        vm.stopPrank();

        address aToken = _getATokenV3(marketParams.collateralToken);
        uint256 aTokenBalance = ERC20(aToken).balanceOf(user);

        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));
        callbackBundle.push(_morphoBorrow(marketParams, borrowed, 0, type(uint256).max, address(bundler)));
        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, false, 1, false));
        callbackBundle.push(_aaveV3Repay(marketParams.loanToken, borrowed / 2));
        callbackBundle.push(_aaveV3Repay(marketParams.loanToken, type(uint256).max));
        callbackBundle.push(_aaveV3PermitAToken(aToken, privateKey, aTokenBalance));
        callbackBundle.push(_erc20TransferFrom(aToken, aTokenBalance));
        callbackBundle.push(_aaveV3Withdraw(marketParams.collateralToken, collateralSupplied));

        bundle.push(_morphoSupplyCollateral(marketParams, collateralSupplied, user));

        vm.prank(user);
        bundler.multicall(bundle);

        _assertBorrowerPosition(collateralSupplied, borrowed, user, address(bundler));
    }

    function testMigrateBorrowerWithPermit2(uint256 privateKey) public {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);

        _provideLiquidity(borrowed);

        deal(marketParams.collateralToken, user, collateralSupplied);

        vm.startPrank(user);
        ERC20(marketParams.collateralToken).safeApprove(AAVE_V3_POOL, collateralSupplied);
        IAaveV3(AAVE_V3_POOL).supply(marketParams.collateralToken, collateralSupplied, user, 0);
        IAaveV3(AAVE_V3_POOL).borrow(marketParams.loanToken, borrowed, RATE_MODE, 0, user);
        vm.stopPrank();

        address aToken = _getATokenV3(marketParams.collateralToken);
        uint256 aTokenBalance = ERC20(aToken).balanceOf(user);

        vm.prank(user);
        ERC20(aToken).safeApprove(address(Permit2Lib.PERMIT2), aTokenBalance);

        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));
        callbackBundle.push(_morphoBorrow(marketParams, borrowed, 0, type(uint256).max, address(bundler)));
        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, false, 1, false));
        callbackBundle.push(_aaveV3Repay(marketParams.loanToken, borrowed / 2));
        callbackBundle.push(_aaveV3Repay(marketParams.loanToken, type(uint256).max));
        callbackBundle.push(_approve2(privateKey, aToken, uint160(aTokenBalance), 0, false));
        callbackBundle.push(_transferFrom2(aToken, aTokenBalance));
        callbackBundle.push(_aaveV3Withdraw(marketParams.collateralToken, collateralSupplied));

        bundle.push(_morphoSupplyCollateral(marketParams, collateralSupplied, user));

        vm.prank(user);
        bundler.multicall(bundle);

        _assertBorrowerPosition(collateralSupplied, borrowed, user, address(bundler));
    }

    function testMigrateUSDTPositionWithPermit2(uint256 privateKey) public onlyEthereum {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);

        uint256 amountUsdt = collateralSupplied / 1e10;

        _initMarket(USDT, WETH);
        _provideLiquidity(borrowed);

        oracle.setPrice(1e46);
        deal(USDT, user, amountUsdt);

        vm.startPrank(user);
        ERC20(USDT).safeApprove(AAVE_V3_POOL, amountUsdt);
        IAaveV3(AAVE_V3_POOL).supply(USDT, amountUsdt, user, 0);
        IAaveV3(AAVE_V3_POOL).borrow(marketParams.loanToken, borrowed, RATE_MODE, 0, user);
        vm.stopPrank();

        address aToken = _getATokenV3(USDT);
        uint256 aTokenBalance = ERC20(aToken).balanceOf(user);

        vm.prank(user);
        ERC20(aToken).safeApprove(address(Permit2Lib.PERMIT2), aTokenBalance);

        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));
        callbackBundle.push(_morphoBorrow(marketParams, borrowed, 0, type(uint256).max, address(bundler)));
        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, false, 1, false));
        callbackBundle.push(_aaveV3Repay(marketParams.loanToken, borrowed / 2));
        callbackBundle.push(_aaveV3Repay(marketParams.loanToken, type(uint256).max));
        callbackBundle.push(_approve2(privateKey, aToken, uint160(aTokenBalance), 0, false));
        callbackBundle.push(_transferFrom2(aToken, aTokenBalance));
        callbackBundle.push(_aaveV3Withdraw(USDT, amountUsdt));

        bundle.push(_morphoSupplyCollateral(marketParams, amountUsdt, user));

        vm.prank(user);
        bundler.multicall(bundle);

        _assertBorrowerPosition(amountUsdt, borrowed, user, address(bundler));
    }

    function testMigrateSupplierWithATokenPermit(uint256 privateKey, uint256 supplied) public {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);
        supplied = bound(supplied, 100, 100 ether);

        deal(marketParams.loanToken, user, supplied + 1);

        vm.startPrank(user);
        ERC20(marketParams.loanToken).safeApprove(AAVE_V3_POOL, supplied + 1);
        IAaveV3(AAVE_V3_POOL).supply(marketParams.loanToken, supplied + 1, user, 0);
        vm.stopPrank();

        address aToken = _getATokenV3(marketParams.loanToken);
        uint256 aTokenBalance = ERC20(aToken).balanceOf(user);

        bundle.push(_aaveV3PermitAToken(aToken, privateKey, aTokenBalance));
        bundle.push(_erc20TransferFrom(aToken, aTokenBalance));
        bundle.push(_aaveV3Withdraw(marketParams.loanToken, supplied));
        bundle.push(_morphoSupply(marketParams, supplied, 0, 0, user));

        vm.prank(user);
        bundler.multicall(bundle);

        _assertSupplierPosition(supplied, user, address(bundler));
    }

    function testMigrateSupplierWithPermit2(uint256 privateKey, uint256 supplied) public {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);
        supplied = bound(supplied, 100, 100 ether);

        deal(marketParams.loanToken, user, supplied + 1);

        vm.startPrank(user);
        ERC20(marketParams.loanToken).safeApprove(AAVE_V3_POOL, supplied + 1);
        IAaveV3(AAVE_V3_POOL).supply(marketParams.loanToken, supplied + 1, user, 0);
        vm.stopPrank();

        address aToken = _getATokenV3(marketParams.loanToken);
        uint256 aTokenBalance = ERC20(aToken).balanceOf(user);

        vm.prank(user);
        ERC20(aToken).safeApprove(address(Permit2Lib.PERMIT2), aTokenBalance);

        bundle.push(_approve2(privateKey, aToken, uint160(aTokenBalance), 0, false));
        bundle.push(_transferFrom2(aToken, aTokenBalance));
        bundle.push(_aaveV3Withdraw(marketParams.loanToken, supplied));
        bundle.push(_morphoSupply(marketParams, supplied, 0, 0, user));

        vm.prank(user);
        bundler.multicall(bundle);

        _assertSupplierPosition(supplied, user, address(bundler));
    }

    function testMigrateSupplierToVaultWithATokenPermit(uint256 privateKey, uint256 supplied) public {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);
        supplied = bound(supplied, 100, 100 ether);

        deal(marketParams.loanToken, user, supplied + 1);

        vm.startPrank(user);
        ERC20(marketParams.loanToken).safeApprove(AAVE_V3_POOL, supplied + 1);
        IAaveV3(AAVE_V3_POOL).supply(marketParams.loanToken, supplied + 1, user, 0);
        vm.stopPrank();

        address aToken = _getATokenV3(marketParams.loanToken);
        uint256 aTokenBalance = ERC20(aToken).balanceOf(user);

        bundle.push(_aaveV3PermitAToken(aToken, privateKey, aTokenBalance));
        bundle.push(_erc20TransferFrom(aToken, aTokenBalance));
        bundle.push(_aaveV3Withdraw(marketParams.loanToken, supplied));
        bundle.push(_erc4626Deposit(address(suppliersVault), supplied, 0, user));

        vm.prank(user);
        bundler.multicall(bundle);

        _assertVaultSupplierPosition(supplied, user, address(bundler));
    }

    function testMigrateSupplierToVaultWithPermit2(uint256 privateKey, uint256 supplied) public {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);
        supplied = bound(supplied, 100, 100 ether);

        deal(marketParams.loanToken, user, supplied + 1);

        vm.startPrank(user);
        ERC20(marketParams.loanToken).safeApprove(AAVE_V3_POOL, supplied + 1);
        IAaveV3(AAVE_V3_POOL).supply(marketParams.loanToken, supplied + 1, user, 0);
        vm.stopPrank();

        address aToken = _getATokenV3(marketParams.loanToken);
        uint256 aTokenBalance = ERC20(aToken).balanceOf(user);

        vm.prank(user);
        ERC20(aToken).safeApprove(address(Permit2Lib.PERMIT2), aTokenBalance);

        bundle.push(_approve2(privateKey, aToken, uint160(aTokenBalance), 0, false));
        bundle.push(_transferFrom2(aToken, aTokenBalance));
        bundle.push(_aaveV3Withdraw(marketParams.loanToken, supplied));
        bundle.push(_erc4626Deposit(address(suppliersVault), supplied, 0, user));

        vm.prank(user);
        bundler.multicall(bundle);

        _assertVaultSupplierPosition(supplied, user, address(bundler));
    }

    function _getATokenV3(address asset) internal view returns (address) {
        return IAaveV3(AAVE_V3_POOL).getReserveData(asset).aTokenAddress;
    }

    /* ACTIONS */

    function _aaveV3PermitAToken(address aToken, uint256 privateKey, uint256 amount)
        internal
        view
        returns (bytes memory)
    {
        address user = vm.addr(privateKey);
        uint256 nonce = IAToken(aToken).nonces(user);

        Permit memory permit = Permit(user, address(bundler), amount, nonce, SIGNATURE_DEADLINE);
        bytes32 hashed = SigUtils.toTypedDataHash(IAToken(aToken).DOMAIN_SEPARATOR(), permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, hashed);

        return abi.encodeCall(PermitBundler.permit, (aToken, amount, SIGNATURE_DEADLINE, v, r, s, false));
    }

    function _aaveV3Repay(address asset, uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeCall(AaveV3MigrationBundlerV2.aaveV3Repay, (asset, amount, RATE_MODE));
    }

    function _aaveV3Withdraw(address asset, uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeCall(AaveV3MigrationBundlerV2.aaveV3Withdraw, (asset, amount));
    }
}
