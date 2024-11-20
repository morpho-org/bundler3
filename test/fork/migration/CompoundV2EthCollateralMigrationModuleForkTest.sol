// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IComptroller} from "../../../src/migration/interfaces/IComptroller.sol";

import "../../../src/migration/CompoundV2MigrationModule.sol";

import "./helpers/MigrationForkTest.sol";

contract CompoundV2EthCollateralMigrationModuleForkTest is MigrationForkTest {
    using MathLib for uint256;
    using SafeTransferLib for ERC20;
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;

    address[] internal enteredMarkets;

    CompoundV2MigrationModule public migrationModule;

    function setUp() public override {
        super.setUp();

        if (block.chainid != 1) return;

        _initMarket(WETH, DAI);

        migrationModule = new CompoundV2MigrationModule(address(bundler), C_ETH_V2);

        enteredMarkets.push(C_ETH_V2);
    }

    function testCompoundV2RepayErc20Unauthorized(uint256 amount) public onlyEthereum {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectPartialRevert(ErrorsLib.UnauthorizedSender.selector);
        migrationModule.compoundV2RepayErc20(C_DAI_V2, amount);
    }


    function testCompoundV2RepayErc20ZeroAmount() public onlyEthereum {
        bundle.push(_compoundV2RepayErc20(C_DAI_V2, 0));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
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
        callbackBundle.push(_morphoBorrow(marketParams, borrowed, 0, type(uint256).max, address(migrationModule)));
        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, false, 1, false));
        callbackBundle.push(_compoundV2RepayErc20(C_DAI_V2, borrowed / 2));
        callbackBundle.push(_compoundV2RepayErc20(C_DAI_V2, type(uint256).max));
        callbackBundle.push(_approve2(privateKey, C_ETH_V2, uint160(cTokenBalance), 0, false));
        callbackBundle.push(_transferFrom2(C_ETH_V2, address(migrationModule), cTokenBalance));
        callbackBundle.push(_compoundV2Redeem(C_ETH_V2, cTokenBalance, address(genericModule1)));
        callbackBundle.push(_wrapNativeNoFunding(collateral, address(genericModule1)));

        bundle.push(_morphoSupplyCollateral(marketParams, collateral, user));

        vm.prank(user);
        bundler.multicall(bundle);

        _assertBorrowerPosition(collateral, borrowed, user, address(genericModule1));
    }

    /* ACTIONS */

    function _compoundV2RepayErc20(address cToken, uint256 repayAmount) internal view returns (Call memory) {
        return _call(migrationModule, abi.encodeCall(migrationModule.compoundV2RepayErc20, (cToken, repayAmount)));
    }

    function _compoundV2Redeem(address cToken, uint256 amount, address receiver) internal view returns (Call memory) {
        return _call(migrationModule, abi.encodeCall(migrationModule.compoundV2Redeem, (cToken, amount, receiver)));
    }
}
