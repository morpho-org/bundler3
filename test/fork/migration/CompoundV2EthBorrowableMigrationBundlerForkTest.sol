// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IComptroller} from "../../../src/migration/interfaces/IComptroller.sol";

import "../../../src/migration/CompoundV2MigrationBundlerV2.sol";

import "./helpers/MigrationForkTest.sol";

contract CompoundV2EthLoanMigrationBundlerForkTest is MigrationForkTest {
    using MathLib for uint256;
    using SafeTransferLib for ERC20;
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;

    address[] internal enteredMarkets;

    CompoundV2MigrationBundlerV2 public migrationBundler;

    function setUp() public override {
        super.setUp();

        if (block.chainid != 1) return;

        _initMarket(DAI, WETH);

        migrationBundler = new CompoundV2MigrationBundlerV2(address(hub), C_ETH_V2);

        enteredMarkets.push(C_DAI_V2);
    }

    function testCompoundV2RepayUnauthorized(uint256 amount) public onlyEthereum {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectPartialRevert(ErrorsLib.UnauthorizedSender.selector);
        migrationBundler.compoundV2Repay(C_DAI_V2, amount);
    }

    function testCompoundV2RedeemUnauthorized(uint256 amount, address receiver) public onlyEthereum {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectPartialRevert(ErrorsLib.UnauthorizedSender.selector);
        migrationBundler.compoundV2Redeem(C_DAI_V2, amount, receiver);
    }

    function testCompoundV2RepayCEthZeroAmount() public onlyEthereum {
        bundle.push(_compoundV2Repay(C_ETH_V2, 0));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        hub.multicall(bundle);
    }

    function testMigrateBorrowerWithPermit2(uint256 privateKey) public onlyEthereum {
        uint256 collateral = 10_000 ether;
        uint256 borrowed = 1 ether;

        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);

        _provideLiquidity(borrowed);

        deal(DAI, user, collateral);

        vm.startPrank(user);
        ERC20(DAI).safeApprove(C_DAI_V2, collateral);
        require(ICToken(C_DAI_V2).mint(collateral) == 0, "mint error");
        require(IComptroller(COMPTROLLER).enterMarkets(enteredMarkets)[0] == 0, "enter market error");
        require(ICEth(C_ETH_V2).borrow(borrowed) == 0, "borrow error");
        vm.stopPrank();

        uint256 cTokenBalance = ICToken(C_DAI_V2).balanceOf(user);
        collateral = cTokenBalance.wMulDown(ICToken(C_DAI_V2).exchangeRateStored());

        vm.prank(user);
        ERC20(C_DAI_V2).safeApprove(address(Permit2Lib.PERMIT2), cTokenBalance);

        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));
        callbackBundle.push(_morphoBorrow(marketParams, borrowed, 0, type(uint256).max, address(genericBundler1)));
        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, false, 1, false));
        callbackBundle.push(_unwrapNative(borrowed, address(migrationBundler)));
        callbackBundle.push(_compoundV2Repay(C_ETH_V2, borrowed / 2));
        callbackBundle.push(_compoundV2Repay(C_ETH_V2, type(uint256).max));
        callbackBundle.push(_approve2(privateKey, C_DAI_V2, uint160(cTokenBalance), 0, false));
        callbackBundle.push(_transferFrom2(C_DAI_V2, address(migrationBundler), cTokenBalance));
        callbackBundle.push(_compoundV2Redeem(C_DAI_V2, cTokenBalance, address(genericBundler1)));

        bundle.push(_morphoSupplyCollateral(marketParams, collateral, user));

        vm.prank(user);
        hub.multicall(bundle);

        _assertBorrowerPosition(collateral, borrowed, user, address(genericBundler1));
    }

    function testMigrateSupplierWithPermit2(uint256 privateKey, uint256 supplied) public onlyEthereum {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);
        supplied = bound(supplied, 0.1 ether, 100 ether);

        deal(user, supplied);

        vm.prank(user);
        ICEth(C_ETH_V2).mint{value: supplied}();

        uint256 cTokenBalance = ICEth(C_ETH_V2).balanceOf(user);
        supplied = cTokenBalance.wMulDown(ICToken(C_ETH_V2).exchangeRateStored());

        vm.prank(user);
        ERC20(C_ETH_V2).safeApprove(address(Permit2Lib.PERMIT2), cTokenBalance);

        bundle.push(_approve2(privateKey, C_ETH_V2, uint160(cTokenBalance), 0, false));
        bundle.push(_transferFrom2(C_ETH_V2, address(migrationBundler), cTokenBalance));
        bundle.push(_compoundV2Redeem(C_ETH_V2, cTokenBalance, address(genericBundler1)));
        bundle.push(_wrapNativeNoFunding(supplied, address(genericBundler1)));
        bundle.push(_morphoSupply(marketParams, supplied, 0, 0, user));

        vm.prank(user);
        hub.multicall(bundle);

        _assertSupplierPosition(supplied, user, address(genericBundler1));
    }

    function testMigrateSupplierToVaultWithPermit2(uint256 privateKey, uint256 supplied) public onlyEthereum {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);
        supplied = bound(supplied, 0.1 ether, 100 ether);

        deal(user, supplied);

        vm.prank(user);
        ICEth(C_ETH_V2).mint{value: supplied}();

        uint256 cTokenBalance = ICEth(C_ETH_V2).balanceOf(user);
        supplied = cTokenBalance.wMulDown(ICToken(C_ETH_V2).exchangeRateStored());

        vm.prank(user);
        ERC20(C_ETH_V2).safeApprove(address(Permit2Lib.PERMIT2), cTokenBalance);

        bundle.push(_approve2(privateKey, C_ETH_V2, uint160(cTokenBalance), 0, false));
        bundle.push(_transferFrom2(C_ETH_V2, address(migrationBundler), cTokenBalance));
        bundle.push(_compoundV2Redeem(C_ETH_V2, cTokenBalance, address(genericBundler1)));
        bundle.push(_wrapNativeNoFunding(supplied, address(genericBundler1)));
        bundle.push(_erc4626Deposit(address(suppliersVault), supplied, 0, user));

        vm.prank(user);
        hub.multicall(bundle);

        _assertVaultSupplierPosition(supplied, user, address(genericBundler1));
    }

    /* ACTIONS */

    function _compoundV2Repay(address cToken, uint256 repayAmount) internal view returns (Call memory) {
        return _call(migrationBundler, abi.encodeCall(migrationBundler.compoundV2Repay, (cToken, repayAmount)));
    }

    function _compoundV2Redeem(address cToken, uint256 amount, address receiver) internal view returns (Call memory) {
        return _call(migrationBundler, abi.encodeCall(migrationBundler.compoundV2Redeem, (cToken, amount, receiver)));
    }
}