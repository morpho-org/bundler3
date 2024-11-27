// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IComptroller} from "../../../src/interfaces/IComptroller.sol";

import "../../../src/migration/CompoundV2MigrationModule.sol";

import "./helpers/MigrationForkTest.sol";

contract CompoundV2EthCollateralMigrationModuleForkTest is MigrationForkTest {
    using MathLib for uint256;
    using SafeTransferLib for ERC20;
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;

    address internal C_ETH_V2 = getAddress("C_ETH_V2");
    address internal C_DAI_V2 = getAddress("C_DAI_V2");
    address internal C_USDC_V2 = getAddress("C_USDC_V2");
    address internal COMPTROLLER = getAddress("COMPTROLLER");
    address internal DAI = getAddress("DAI");
    address internal WETH = getAddress("WETH");

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
        migrationModule.compoundV2RepayErc20(C_DAI_V2, amount, address(this));
    }

    function testCompoundV2RepayErc20ZeroAmount() public onlyEthereum {
        bundle.push(_compoundV2RepayErc20(C_DAI_V2, 0, address(this)));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        bundler.multicall(bundle);
    }

    function testCompoundV2RepayErc20Max(uint256 borrowed, uint256 repayFactor) public onlyEthereum {
        uint256 collateral = 10_000 ether;
        borrowed = bound(borrowed, 0.1 ether, 10 ether);
        repayFactor = bound(repayFactor, 0.01 ether, 0.99 ether);
        uint256 toRepay = borrowed.wMulDown(repayFactor);

        deal(address(this), collateral);

        ICEth(C_ETH_V2).mint{value: collateral}();
        require(IComptroller(COMPTROLLER).enterMarkets(enteredMarkets)[0] == 0, "enter market error");
        require(ICToken(C_DAI_V2).borrow(borrowed) == 0, "borrow error");

        ERC20(DAI).safeTransfer(address(migrationModule), toRepay);

        bundle.push(_compoundV2RepayErc20(C_DAI_V2, type(uint256).max, address(this)));
        bundler.multicall(bundle);

        assertEq(ICToken(C_DAI_V2).borrowBalanceCurrent(address(this)), borrowed - toRepay);
    }

    function testCompoundV2RepayErc20NotMax(uint256 borrowed, uint256 repayFactor) public onlyEthereum {
        uint256 collateral = 10_000 ether;
        borrowed = bound(borrowed, 0.1 ether, 10 ether);
        repayFactor = bound(repayFactor, 0.01 ether, 10 ether);
        uint256 toRepay = borrowed.wMulDown(repayFactor);

        deal(USER, collateral);

        vm.startPrank(USER);
        ICEth(C_ETH_V2).mint{value: collateral}();
        require(IComptroller(COMPTROLLER).enterMarkets(enteredMarkets)[0] == 0, "enter market error");
        require(ICToken(C_DAI_V2).borrow(borrowed) == 0, "borrow error");
        vm.stopPrank();

        deal(DAI, address(this), toRepay);
        ERC20(DAI).safeTransfer(address(migrationModule), toRepay);

        bundle.push(_compoundV2RepayErc20(C_DAI_V2, toRepay, USER));
        bundler.multicall(bundle);

        if (repayFactor < 1 ether) {
            assertEq(ICToken(C_DAI_V2).borrowBalanceCurrent(USER), borrowed - toRepay);
        } else {
            assertEq(ICToken(C_DAI_V2).borrowBalanceCurrent(USER), 0);
        }
    }

    function testCompoundV2RedeemEthNotMax(uint256 supplied, uint256 redeemFactor) public onlyEthereum {
        supplied = bound(supplied, 0.1 ether, 100 ether);
        redeemFactor = bound(redeemFactor, 0.1 ether, 100 ether);
        deal(address(this), supplied);
        ICEth(C_ETH_V2).mint{value: supplied}();
        uint256 minted = ICToken(C_ETH_V2).balanceOf(address(this));
        ERC20(C_ETH_V2).safeTransfer(address(migrationModule), minted);
        uint256 toRedeem = minted.wMulDown(redeemFactor);
        bundle.push(_compoundV2RedeemEth(toRedeem, address(migrationModule)));
        bundler.multicall(bundle);

        if (redeemFactor < 1 ether) {
            assertEq(ERC20(C_ETH_V2).balanceOf(address(migrationModule)), minted - toRedeem);
        } else {
            assertEq(ERC20(C_ETH_V2).balanceOf(address(this)), 0);
        }
    }

    function testMigrateBorrowerWithPermit2() public onlyEthereum {
        uint256 collateral = 10 ether;
        uint256 borrowed = 1 ether;

        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);

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
        callbackBundle.push(_compoundV2RepayErc20(C_DAI_V2, borrowed / 2, user));
        callbackBundle.push(_compoundV2RepayErc20(C_DAI_V2, type(uint256).max, user));
        callbackBundle.push(_approve2(privateKey, C_ETH_V2, uint160(cTokenBalance), 0, false));
        callbackBundle.push(_transferFrom2(C_ETH_V2, address(migrationModule), cTokenBalance));
        callbackBundle.push(_compoundV2RedeemEth(cTokenBalance, address(genericModule1)));
        callbackBundle.push(_wrapNativeNoFunding(collateral, address(genericModule1)));

        bundle.push(_morphoSupplyCollateral(marketParams, collateral, user, abi.encode(callbackBundle)));

        vm.prank(user);
        bundler.multicall(bundle);

        _assertBorrowerPosition(collateral, borrowed, user, address(genericModule1));
    }

    /* ACTIONS */

    function _compoundV2RepayErc20(address cToken, uint256 repayAmount, address onBehalf)
        internal
        view
        returns (Call memory)
    {
        return _call(
            migrationModule, abi.encodeCall(migrationModule.compoundV2RepayErc20, (cToken, repayAmount, onBehalf))
        );
    }

    function _compoundV2RedeemEth(uint256 amount, address receiver) internal view returns (Call memory) {
        return _call(migrationModule, abi.encodeCall(migrationModule.compoundV2RedeemEth, (amount, receiver)));
    }
}
