// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IComptroller} from "../../../src/migration/interfaces/IComptroller.sol";

import "../../../src/migration/CompoundV2MigrationBundlerV2.sol";

import "./helpers/MigrationForkTest.sol";

contract CompoundV2NoEthMigrationBundlerForkTest is MigrationForkTest {
    using MathLib for uint256;
    using SafeTransferLib for ERC20;
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;

    address[] internal enteredMarkets;

    function setUp() public override {
        super.setUp();

        if (block.chainid != 1) return;

        _initMarket(DAI, USDC);

        bundler = new CompoundV2MigrationBundlerV2(address(morpho), WETH, C_ETH_V2);

        enteredMarkets.push(C_DAI_V2);
    }

    function testCompoundV2RedeemZeroAmount() public onlyEthereum {
        bundle.push(_compoundV2Redeem(C_USDC_V2, 0));

        vm.expectRevert(bytes(ErrorsLib.ZERO_AMOUNT));
        bundler.multicall(bundle);
    }

    function testMigrateBorrowerWithPermit2(uint256 privateKey) public onlyEthereum {
        uint256 collateral = 10 ether;
        uint256 borrowed = 1e6;

        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);

        _provideLiquidity(borrowed);

        deal(marketParams.collateralToken, user, collateral);

        vm.startPrank(user);
        ERC20(marketParams.collateralToken).safeApprove(C_DAI_V2, collateral);
        require(ICToken(C_DAI_V2).mint(collateral) == 0, "mint error");
        require(IComptroller(COMPTROLLER).enterMarkets(enteredMarkets)[0] == 0, "enter market error");
        require(ICToken(C_USDC_V2).borrow(borrowed) == 0, "borrow error");
        vm.stopPrank();

        uint256 cTokenBalance = ICToken(C_DAI_V2).balanceOf(user);
        collateral = cTokenBalance.wMulDown(ICToken(C_DAI_V2).exchangeRateStored());

        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));
        callbackBundle.push(_morphoBorrow(marketParams, borrowed, 0, type(uint256).max, address(bundler)));
        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, false, 1, false));
        callbackBundle.push(_compoundV2Repay(C_USDC_V2, borrowed / 2));
        callbackBundle.push(_compoundV2Repay(C_USDC_V2, type(uint256).max));
        callbackBundle.push(_approve2(privateKey, C_DAI_V2, uint160(cTokenBalance), 0, false));
        callbackBundle.push(_transferFrom2(C_DAI_V2, cTokenBalance));
        callbackBundle.push(_compoundV2Redeem(C_DAI_V2, cTokenBalance));

        bundle.push(_morphoSupplyCollateral(marketParams, collateral, user));

        vm.startPrank(user);
        ERC20(C_DAI_V2).safeApprove(address(Permit2Lib.PERMIT2), cTokenBalance);
        bundler.multicall(bundle);
        vm.stopPrank();

        _assertBorrowerPosition(collateral, borrowed, user, address(bundler));
    }

    function testMigrateSupplierWithPermit2(uint256 privateKey, uint256 supplied) public onlyEthereum {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);
        supplied = bound(supplied, 100, 100 ether);

        deal(marketParams.loanToken, user, supplied);

        vm.startPrank(user);
        ERC20(marketParams.loanToken).safeApprove(C_USDC_V2, supplied);
        require(ICToken(C_USDC_V2).mint(supplied) == 0, "mint error");
        vm.stopPrank();

        uint256 cTokenBalance = ICToken(C_USDC_V2).balanceOf(user);
        supplied = cTokenBalance.wMulDown(ICToken(C_USDC_V2).exchangeRateStored());

        vm.prank(user);
        ERC20(C_USDC_V2).safeApprove(address(Permit2Lib.PERMIT2), cTokenBalance);

        bundle.push(_approve2(privateKey, C_USDC_V2, uint160(cTokenBalance), 0, false));
        bundle.push(_transferFrom2(C_USDC_V2, cTokenBalance));
        bundle.push(_compoundV2Redeem(C_USDC_V2, cTokenBalance));
        bundle.push(_morphoSupply(marketParams, supplied, 0, 0, user));

        vm.prank(user);
        bundler.multicall(bundle);

        _assertSupplierPosition(supplied, user, address(bundler));
    }

    function testMigrateSupplierToVaultWithPermit2(uint256 privateKey, uint256 supplied) public onlyEthereum {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);
        supplied = bound(supplied, 100, 100 ether);

        deal(marketParams.loanToken, user, supplied);

        vm.startPrank(user);
        ERC20(marketParams.loanToken).safeApprove(C_USDC_V2, supplied);
        require(ICToken(C_USDC_V2).mint(supplied) == 0, "mint error");
        vm.stopPrank();

        uint256 cTokenBalance = ICToken(C_USDC_V2).balanceOf(user);
        supplied = cTokenBalance.wMulDown(ICToken(C_USDC_V2).exchangeRateStored());

        vm.prank(user);
        ERC20(C_USDC_V2).safeApprove(address(Permit2Lib.PERMIT2), cTokenBalance);

        bundle.push(_approve2(privateKey, C_USDC_V2, uint160(cTokenBalance), 0, false));
        bundle.push(_transferFrom2(C_USDC_V2, cTokenBalance));
        bundle.push(_compoundV2Redeem(C_USDC_V2, cTokenBalance));
        bundle.push(_erc4626Deposit(address(suppliersVault), supplied, 0, user));

        vm.prank(user);
        bundler.multicall(bundle);

        _assertVaultSupplierPosition(supplied, user, address(bundler));
    }

    /* ACTIONS */

    function _compoundV2Repay(address cToken, uint256 repayAmount) internal pure returns (bytes memory) {
        return abi.encodeCall(CompoundV2MigrationBundlerV2.compoundV2Repay, (cToken, repayAmount));
    }

    function _compoundV2Redeem(address cToken, uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeCall(CompoundV2MigrationBundlerV2.compoundV2Redeem, (cToken, amount));
    }
}
