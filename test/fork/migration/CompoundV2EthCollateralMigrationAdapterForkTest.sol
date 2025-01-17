// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IComptroller} from "../../../src/interfaces/IComptroller.sol";

import "../../../src/adapters/migration/CompoundV2MigrationAdapter.sol";

import "./helpers/MigrationForkTest.sol";

contract CompoundV2EthCollateralMigrationAdapterForkTest is MigrationForkTest {
    using MathLib for uint256;
    using SafeERC20 for IERC20;
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;

    address internal immutable C_ETH_V2 = getAddress("C_ETH_V2");
    address internal immutable C_DAI_V2 = getAddress("C_DAI_V2");
    address internal immutable C_USDC_V2 = getAddress("C_USDC_V2");
    address internal immutable COMPTROLLER = getAddress("COMPTROLLER");
    address internal immutable DAI = getAddress("DAI");
    address internal immutable WETH = getAddress("WETH");

    address[] internal enteredMarkets;

    CompoundV2MigrationAdapter internal migrationAdapter;

    function setUp() public override {
        super.setUp();

        if (block.chainid != 1) return;

        _initMarket(WETH, DAI);

        migrationAdapter = new CompoundV2MigrationAdapter(address(bundler3), C_ETH_V2);

        enteredMarkets.push(C_ETH_V2);
    }

    function testCompoundV2RepayErc20Unauthorized(uint256 amount) public onlyEthereum {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(ErrorsLib.UnauthorizedSender.selector);
        migrationAdapter.compoundV2RepayErc20(C_DAI_V2, amount, address(this));
    }

    function testCompoundV2RepayErc20ZeroAmount() public onlyEthereum {
        bundle.push(_compoundV2RepayErc20(C_DAI_V2, 0, address(this)));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        bundler3.multicall(bundle);
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

        IERC20(DAI).safeTransfer(address(migrationAdapter), toRepay);

        bundle.push(_compoundV2RepayErc20(C_DAI_V2, type(uint256).max, address(this)));
        bundler3.multicall(bundle);

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
        IERC20(DAI).safeTransfer(address(migrationAdapter), toRepay);

        bundle.push(_compoundV2RepayErc20(C_DAI_V2, toRepay, USER));
        bundler3.multicall(bundle);

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
        IERC20(C_ETH_V2).safeTransfer(address(migrationAdapter), minted);
        uint256 toRedeem = minted.wMulDown(redeemFactor);
        bundle.push(_compoundV2RedeemEth(toRedeem, address(migrationAdapter)));
        bundler3.multicall(bundle);

        if (redeemFactor < 1 ether) {
            assertEq(IERC20(C_ETH_V2).balanceOf(address(migrationAdapter)), minted - toRedeem);
        } else {
            assertEq(IERC20(C_ETH_V2).balanceOf(address(this)), 0);
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
        IERC20(C_ETH_V2).forceApprove(address(Permit2Lib.PERMIT2), cTokenBalance);

        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));
        callbackBundle.push(_morphoBorrow(marketParams, borrowed, 0, 0, address(migrationAdapter)));
        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, false, 1, false));
        callbackBundle.push(_compoundV2RepayErc20(C_DAI_V2, borrowed / 2, user));
        callbackBundle.push(_compoundV2RepayErc20(C_DAI_V2, type(uint256).max, user));
        callbackBundle.push(_approve2(privateKey, C_ETH_V2, uint160(cTokenBalance), 0, false));
        callbackBundle.push(_permit2TransferFrom(C_ETH_V2, address(migrationAdapter), cTokenBalance));
        callbackBundle.push(_compoundV2RedeemEth(cTokenBalance, address(generalAdapter1)));
        callbackBundle.push(_wrapNativeNoFunding(collateral, address(generalAdapter1)));

        bundle.push(_morphoSupplyCollateral(marketParams, collateral, user, abi.encode(callbackBundle)));

        vm.prank(user);
        bundler3.multicall(bundle);

        _assertBorrowerPosition(collateral, borrowed, user, address(generalAdapter1));
    }

    /* ACTIONS */

    function _compoundV2RepayErc20(address cToken, uint256 repayAmount, address onBehalf)
        internal
        view
        returns (Call memory)
    {
        return _call(
            migrationAdapter, abi.encodeCall(migrationAdapter.compoundV2RepayErc20, (cToken, repayAmount, onBehalf))
        );
    }

    function _compoundV2RedeemEth(uint256 amount, address receiver) internal view returns (Call memory) {
        return _call(migrationAdapter, abi.encodeCall(migrationAdapter.compoundV2RedeemEth, (amount, receiver)));
    }
}
