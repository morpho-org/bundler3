// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IStEth} from "../../../../src/interfaces/IStEth.sol";
import {IAaveV2} from "../../../../src/migration/interfaces/IAaveV2.sol";
import {IERC4626} from "../../../../lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

import "../../../../src/migration/AaveV2MigrationBundlerV2.sol";

import "./helpers/MigrationForkTest.sol";

contract AaveV2MigrationBundlerForkTest is MigrationForkTest {
    using SafeTransferLib for ERC20;
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;

    uint256 public constant RATE_MODE = 2;

    uint256 collateralSupplied = 10_000 ether;
    uint256 borrowed = 1 ether;

    function setUp() public override {
        super.setUp();

        if (block.chainid != 1) return;

        _initMarket(DAI, WETH);

        vm.label(AAVE_V2_POOL, "Aave V2 Pool");

        bundler = new AaveV2MigrationBundlerV2(address(morpho), AAVE_V2_POOL, WST_ETH);
    }

    function testAaveV2RepayUninitiated(uint256 amount) public onlyEthereum {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(bytes(ErrorsLib.UNINITIATED));
        AaveV2MigrationBundlerV2(address(bundler)).aaveV2Repay(marketParams.loanToken, amount, 1);
    }

    function testAaveV2WithdrawUninitiated(uint256 amount) public onlyEthereum {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(bytes(ErrorsLib.UNINITIATED));
        AaveV2MigrationBundlerV2(address(bundler)).aaveV2Withdraw(marketParams.loanToken, amount);
    }

    function testAaveV2RepayZeroAmount() public onlyEthereum {
        bundle.push(_aaveV2Repay(marketParams.loanToken, 0));

        vm.expectRevert(bytes(ErrorsLib.ZERO_AMOUNT));
        bundler.multicall(bundle);
    }

    function testMigrateBorrowerWithPermit2(uint256 privateKey) public onlyEthereum {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);

        _provideLiquidity(borrowed);

        deal(marketParams.collateralToken, user, collateralSupplied);

        vm.startPrank(user);
        ERC20(marketParams.collateralToken).safeApprove(AAVE_V2_POOL, collateralSupplied);
        IAaveV2(AAVE_V2_POOL).deposit(marketParams.collateralToken, collateralSupplied, user, 0);
        IAaveV2(AAVE_V2_POOL).borrow(marketParams.loanToken, borrowed, RATE_MODE, 0, user);
        vm.stopPrank();

        address aToken = _getATokenV2(marketParams.collateralToken);
        uint256 aTokenBalance = ERC20(aToken).balanceOf(user);

        vm.prank(user);
        ERC20(aToken).safeApprove(address(Permit2Lib.PERMIT2), aTokenBalance);

        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));
        callbackBundle.push(_morphoBorrow(marketParams, borrowed, 0, type(uint256).max, address(bundler)));
        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, false, 1, false));
        callbackBundle.push(_aaveV2Repay(marketParams.loanToken, borrowed / 2));
        callbackBundle.push(_aaveV2Repay(marketParams.loanToken, type(uint256).max));
        callbackBundle.push(_approve2(privateKey, aToken, uint160(aTokenBalance), 0, false));
        callbackBundle.push(_transferFrom2(aToken, aTokenBalance));
        callbackBundle.push(_aaveV2Withdraw(marketParams.collateralToken, collateralSupplied));

        bundle.push(_morphoSupplyCollateral(marketParams, collateralSupplied, user));

        vm.prank(user);
        bundler.multicall(bundle);

        _assertBorrowerPosition(collateralSupplied, borrowed, user, address(bundler));
    }

    function testMigrateBorrowerDaiToSDaiWithPermit2(uint256 privateKey) public onlyEthereum {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);

        _initMarket(S_DAI, WETH);
        _provideLiquidity(borrowed);

        deal(DAI, user, collateralSupplied);

        vm.startPrank(user);
        ERC20(DAI).safeApprove(AAVE_V2_POOL, collateralSupplied);
        IAaveV2(AAVE_V2_POOL).deposit(DAI, collateralSupplied, user, 0);
        IAaveV2(AAVE_V2_POOL).borrow(marketParams.loanToken, borrowed, RATE_MODE, 0, user);
        vm.stopPrank();

        address aToken = _getATokenV2(DAI);
        uint256 aTokenBalance = ERC20(aToken).balanceOf(user);

        vm.prank(user);
        ERC20(aToken).safeApprove(address(Permit2Lib.PERMIT2), aTokenBalance);

        uint256 sDaiAmount = IERC4626(S_DAI).previewDeposit(collateralSupplied);

        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));
        callbackBundle.push(_morphoBorrow(marketParams, borrowed, 0, type(uint256).max, address(bundler)));
        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, false, 1, false));
        callbackBundle.push(_aaveV2Repay(marketParams.loanToken, borrowed / 2));
        callbackBundle.push(_aaveV2Repay(marketParams.loanToken, type(uint256).max));
        callbackBundle.push(_approve2(privateKey, aToken, uint160(aTokenBalance), 0, false));
        callbackBundle.push(_transferFrom2(aToken, aTokenBalance));
        callbackBundle.push(_aaveV2Withdraw(DAI, collateralSupplied));
        callbackBundle.push(_erc4626Deposit(S_DAI, collateralSupplied, 0, address(bundler)));

        bundle.push(_morphoSupplyCollateral(marketParams, sDaiAmount, user));

        vm.prank(user);
        bundler.multicall(bundle);

        _assertBorrowerPosition(sDaiAmount, borrowed, user, address(bundler));
    }

    function testMigrateStEthPositionWithPermit2(uint256 privateKey) public onlyEthereum {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);

        _initMarket(WST_ETH, marketParams.loanToken);
        _provideLiquidity(borrowed);

        deal(ST_ETH, user, collateralSupplied);

        collateralSupplied = ERC20(ST_ETH).balanceOf(user);

        vm.startPrank(user);
        ERC20(ST_ETH).safeApprove(AAVE_V2_POOL, collateralSupplied);
        IAaveV2(AAVE_V2_POOL).deposit(ST_ETH, collateralSupplied, user, 0);
        IAaveV2(AAVE_V2_POOL).borrow(marketParams.loanToken, borrowed, RATE_MODE, 0, user);
        vm.stopPrank();

        // The amount of stEth as collateral is decreased by 10 beceause of roundings.
        collateralSupplied -= 10;

        address aToken = _getATokenV2(ST_ETH);
        uint256 aTokenBalance = ERC20(aToken).balanceOf(user);

        uint256 wstEthAmount = IStEth(ST_ETH).getSharesByPooledEth(collateralSupplied);

        vm.prank(user);
        ERC20(aToken).safeApprove(address(Permit2Lib.PERMIT2), aTokenBalance);

        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));
        callbackBundle.push(_morphoBorrow(marketParams, borrowed, 0, type(uint256).max, address(bundler)));
        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, false, 1, false));
        callbackBundle.push(_aaveV2Repay(marketParams.loanToken, borrowed / 2));
        callbackBundle.push(_aaveV2Repay(marketParams.loanToken, type(uint256).max));
        callbackBundle.push(_approve2(privateKey, aToken, type(uint160).max, 0, false));
        callbackBundle.push(_transferFrom2(aToken, aTokenBalance));
        callbackBundle.push(_aaveV2Withdraw(ST_ETH, type(uint256).max));
        callbackBundle.push(_wrapStEth(type(uint256).max));

        bundle.push(_morphoSupplyCollateral(marketParams, wstEthAmount, user));

        vm.prank(user);
        bundler.multicall(bundle);

        _assertBorrowerPosition(wstEthAmount, borrowed, user, address(bundler));
    }

    function testMigrateSupplierWithPermit2(uint256 privateKey, uint256 supplied) public onlyEthereum {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);
        supplied = bound(supplied, 100, 100 ether);

        deal(marketParams.loanToken, user, supplied + 1);

        vm.startPrank(user);
        ERC20(marketParams.loanToken).safeApprove(AAVE_V2_POOL, supplied + 1);
        IAaveV2(AAVE_V2_POOL).deposit(marketParams.loanToken, supplied + 1, user, 0);
        vm.stopPrank();

        address aToken = _getATokenV2(marketParams.loanToken);
        uint256 aTokenBalance = ERC20(aToken).balanceOf(user);

        vm.prank(user);
        ERC20(aToken).safeApprove(address(Permit2Lib.PERMIT2), aTokenBalance);

        bundle.push(_approve2(privateKey, aToken, uint160(aTokenBalance), 0, false));
        bundle.push(_transferFrom2(aToken, aTokenBalance));
        bundle.push(_aaveV2Withdraw(marketParams.loanToken, supplied));
        bundle.push(_morphoSupply(marketParams, supplied, 0, 0, user));

        vm.prank(user);
        bundler.multicall(bundle);

        _assertSupplierPosition(supplied, user, address(bundler));
    }

    function testMigrateSupplierToVaultWithPermit2(uint256 privateKey, uint256 supplied) public onlyEthereum {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);
        supplied = bound(supplied, 100, 100 ether);

        deal(marketParams.loanToken, user, supplied + 1);

        vm.startPrank(user);
        ERC20(marketParams.loanToken).safeApprove(AAVE_V2_POOL, supplied + 1);
        IAaveV2(AAVE_V2_POOL).deposit(marketParams.loanToken, supplied + 1, user, 0);
        vm.stopPrank();

        address aToken = _getATokenV2(marketParams.loanToken);
        uint256 aTokenBalance = ERC20(aToken).balanceOf(user);

        vm.prank(user);
        ERC20(aToken).safeApprove(address(Permit2Lib.PERMIT2), aTokenBalance);

        bundle.push(_approve2(privateKey, aToken, uint160(aTokenBalance), 0, false));
        bundle.push(_transferFrom2(aToken, aTokenBalance));
        bundle.push(_aaveV2Withdraw(marketParams.loanToken, supplied));
        bundle.push(_erc4626Deposit(address(suppliersVault), supplied, 0, user));

        vm.prank(user);
        bundler.multicall(bundle);

        _assertVaultSupplierPosition(supplied, user, address(bundler));
    }

    function _getATokenV2(address asset) internal view returns (address) {
        return IAaveV2(AAVE_V2_POOL).getReserveData(asset).aTokenAddress;
    }

    /* ACTIONS */

    function _aaveV2Repay(address asset, uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeCall(AaveV2MigrationBundlerV2.aaveV2Repay, (asset, amount, RATE_MODE));
    }

    function _aaveV2Withdraw(address asset, uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeCall(AaveV2MigrationBundlerV2.aaveV2Withdraw, (asset, amount));
    }
}
