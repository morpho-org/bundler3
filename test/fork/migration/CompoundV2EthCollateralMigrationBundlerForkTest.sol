// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IComptroller} from "../../../src/migration/interfaces/IComptroller.sol";

import "../../../src/migration/CompoundV2MigrationBundlerV2.sol";

import "./helpers/MigrationForkTest.sol";

contract CompoundV2EthCollateralMigrationBundlerForkTest is MigrationForkTest {
    using MathLib for uint256;
    using SafeTransferLib for ERC20;
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;

    address[] internal enteredMarkets;

    function setUp() public override {
        super.setUp();

        if (block.chainid != 1) return;

        _initMarket(WETH, DAI);

        bundler = new CompoundV2MigrationBundlerV2(address(morpho), WETH, C_ETH_V2);

        enteredMarkets.push(C_ETH_V2);
    }

    function testCompoundV2RepayZeroAmount() public onlyEthereum {
        bundle.push(_compoundV2Repay(C_DAI_V2, 0));

        vm.expectRevert(bytes(ErrorsLib.ZERO_AMOUNT));
        bundler.multicall(bundle);
    }

    function testMigrateBorrowerWithPermit2(uint256 privateKey) public onlyEthereum {
        uint256 collateral = 10 ether;
        uint256 borrowed = 1 ether;

        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);

        _provideLiquidity(borrowed);

        deal(user, collateral);

        vm.startPrank(user);
        ICEth(C_ETH_V2).mint{value: collateral}();
        require(IComptroller(COMPTROLLER).enterMarkets(enteredMarkets)[0] == 0, "enter market error");
        require(ICToken(C_DAI_V2).borrow(borrowed) == 0, "borrow error");
        vm.stopPrank();

        uint256 cTokenBalance = ICEth(C_ETH_V2).balanceOf(user);
        collateral = cTokenBalance.wMulDown(ICToken(C_ETH_V2).exchangeRateStored());

        vm.prank(user);
        ERC20(C_ETH_V2).safeApprove(address(Permit2Lib.PERMIT2), cTokenBalance);

        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));
        callbackBundle.push(_morphoBorrow(marketParams, borrowed, 0, type(uint256).max, address(bundler)));
        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, false, 1, false));
        callbackBundle.push(_compoundV2Repay(C_DAI_V2, borrowed / 2));
        callbackBundle.push(_compoundV2Repay(C_DAI_V2, type(uint256).max));
        callbackBundle.push(_approve2(privateKey, C_ETH_V2, uint160(cTokenBalance), 0, false));
        callbackBundle.push(_transferFrom2(C_ETH_V2, cTokenBalance));
        callbackBundle.push(_compoundV2Redeem(C_ETH_V2, cTokenBalance));
        callbackBundle.push(_wrapNative(collateral));

        bundle.push(_morphoSupplyCollateral(marketParams, collateral, user));

        vm.prank(user);
        bundler.multicall(bundle);

        _assertBorrowerPosition(collateral, borrowed, user, address(bundler));
    }

    /* ACTIONS */

    function _compoundV2Repay(address cToken, uint256 repayAmount) internal pure returns (bytes memory) {
        return abi.encodeCall(CompoundV2MigrationBundlerV2.compoundV2Repay, (cToken, repayAmount));
    }

    function _compoundV2Redeem(address cToken, uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeCall(CompoundV2MigrationBundlerV2.compoundV2Redeem, (cToken, amount));
    }
}
