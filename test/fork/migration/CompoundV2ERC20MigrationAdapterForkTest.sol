// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IComptroller} from "../../../src/interfaces/IComptroller.sol";

import "../../../src/adapters/migration/CompoundV2MigrationAdapter.sol";

import "./helpers/MigrationForkTest.sol";

contract CompoundV2ERC20MigrationAdapterForkTest is MigrationForkTest {
    using MathLib for uint256;
    using SafeERC20 for IERC20;
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;

    address internal immutable C_USDC_V2 = getAddress("C_USDC_V2");
    address internal immutable C_DAI_V2 = getAddress("C_DAI_V2");
    address internal immutable COMPTROLLER = getAddress("COMPTROLLER");
    address internal immutable DAI = getAddress("DAI");
    address internal immutable USDC = getAddress("USDC");
    address internal immutable C_ETH_V2 = getAddress("C_ETH_V2");

    address[] internal enteredMarkets;

    CompoundV2MigrationAdapter internal migrationAdapter;

    function setUp() public override {
        super.setUp();

        if (block.chainid != 1) return;

        _initMarket(DAI, USDC);

        migrationAdapter = new CompoundV2MigrationAdapter(address(bundler3), C_ETH_V2);

        enteredMarkets.push(C_DAI_V2);
    }

    function testCompoundV2RepayCeth() public onlyEthereum {
        bundle.push(_compoundV2RepayErc20(C_ETH_V2, 1, address(this)));

        vm.expectRevert(ErrorsLib.CTokenIsCETH.selector);
        bundler3.multicall(bundle);
    }

    function testCompoundV2RedeemCeth() public onlyEthereum {
        bundle.push(_compoundV2RedeemErc20(C_ETH_V2, 1, address(this)));

        vm.expectRevert(ErrorsLib.CTokenIsCETH.selector);
        bundler3.multicall(bundle);
    }

    function testCompoundV2RedeemErc20Unauthorized(uint256 amount, address receiver) public onlyEthereum {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(ErrorsLib.UnauthorizedSender.selector);
        migrationAdapter.compoundV2RedeemErc20(C_DAI_V2, amount, receiver);
    }

    function testCompoundV2RedeemErc20ZeroAmount() public onlyEthereum {
        bundle.push(_compoundV2RedeemErc20(C_USDC_V2, 0, address(this)));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        bundler3.multicall(bundle);
    }

    function testCompoundV2RedeemErc20NotMax(uint256 supplied, uint256 redeemFactor) public onlyEthereum {
        supplied = bound(supplied, MIN_AMOUNT, MAX_AMOUNT);
        redeemFactor = bound(redeemFactor, 0.1 ether, 100 ether);
        deal(USDC, address(this), supplied);
        IERC20(USDC).forceApprove(C_USDC_V2, supplied);
        require(ICToken(C_USDC_V2).mint(supplied) == 0, "mint error");
        uint256 minted = ICToken(C_USDC_V2).balanceOf(address(this));
        IERC20(C_USDC_V2).safeTransfer(address(migrationAdapter), minted);

        uint256 toRedeem = minted.wMulDown(redeemFactor);
        bundle.push(_compoundV2RedeemErc20(C_USDC_V2, toRedeem, address(this)));
        bundler3.multicall(bundle);

        if (redeemFactor < 1 ether) {
            assertEq(IERC20(C_USDC_V2).balanceOf(address(migrationAdapter)), minted - toRedeem);
        } else {
            assertEq(IERC20(C_USDC_V2).balanceOf(address(this)), 0);
        }
    }

    function testMigrateBorrowerWithPermit2() public onlyEthereum {
        uint256 collateral = 10 ether;
        uint256 borrowed = 1e6;
        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);

        _provideLiquidity(borrowed);

        deal(marketParams.collateralToken, user, collateral);

        vm.startPrank(user);
        IERC20(marketParams.collateralToken).forceApprove(C_DAI_V2, collateral);
        require(ICToken(C_DAI_V2).mint(collateral) == 0, "mint error");
        require(IComptroller(COMPTROLLER).enterMarkets(enteredMarkets)[0] == 0, "enter market error");
        require(ICToken(C_USDC_V2).borrow(borrowed) == 0, "borrow error");
        vm.stopPrank();

        uint256 cTokenBalance = ICToken(C_DAI_V2).balanceOf(user);
        collateral = cTokenBalance.wMulDown(ICToken(C_DAI_V2).exchangeRateStored());

        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));
        callbackBundle.push(_morphoBorrow(marketParams, borrowed, 0, 0, address(migrationAdapter)));
        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, false, 1, false));
        callbackBundle.push(_compoundV2RepayErc20(C_USDC_V2, borrowed / 2, user));
        callbackBundle.push(_compoundV2RepayErc20(C_USDC_V2, type(uint256).max, user));
        callbackBundle.push(_approve2(privateKey, C_DAI_V2, uint160(cTokenBalance), 0, false));
        callbackBundle.push(_permit2TransferFrom(C_DAI_V2, address(migrationAdapter), cTokenBalance));
        callbackBundle.push(_compoundV2RedeemErc20(C_DAI_V2, cTokenBalance, address(generalAdapter1)));

        bundle.push(_morphoSupplyCollateral(marketParams, collateral, user, abi.encode(callbackBundle)));

        vm.startPrank(user);
        IERC20(C_DAI_V2).forceApprove(address(Permit2Lib.PERMIT2), cTokenBalance);
        bundler3.multicall(bundle);
        vm.stopPrank();

        _assertBorrowerPosition(collateral, borrowed, user, address(generalAdapter1));

        assertEq(
            IERC20(marketParams.loanToken).allowance(address(migrationAdapter), address(C_USDC_V2)),
            0,
            "loanToken.allowance(migrationAdapter, C_USDC_V2)"
        );
    }

    function testCompoundV2RepayOnBehalf() public onlyEthereum {
        uint256 collateral = 10 ether;
        uint256 borrowed = 1e6;

        _provideLiquidity(borrowed);

        deal(marketParams.collateralToken, USER, collateral);

        vm.startPrank(USER);
        IERC20(marketParams.collateralToken).forceApprove(C_DAI_V2, collateral);
        require(ICToken(C_DAI_V2).mint(collateral) == 0, "mint error");
        require(IComptroller(COMPTROLLER).enterMarkets(enteredMarkets)[0] == 0, "enter market error");
        require(ICToken(C_USDC_V2).borrow(borrowed) == 0, "borrow error");
        vm.stopPrank();

        bundle.push(_compoundV2RepayErc20(C_USDC_V2, type(uint256).max, USER));

        deal(USDC, address(migrationAdapter), borrowed);

        require(ICToken(C_USDC_V2).borrowBalanceCurrent(USER) == borrowed, "borrow balance current");

        bundler3.multicall(bundle);

        require(ICToken(C_USDC_V2).borrowBalanceCurrent(USER) == 0, "borrow balance current");

        assertEq(
            IERC20(marketParams.loanToken).allowance(address(migrationAdapter), address(C_USDC_V2)),
            0,
            "loanToken.allowance(migrationAdapter, C_USDC_V2)"
        );
    }

    function testMigrateSupplierWithPermit2(uint256 supplied) public onlyEthereum {
        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);
        supplied = bound(supplied, 100, 100 ether);

        deal(marketParams.loanToken, user, supplied);

        vm.startPrank(user);
        IERC20(marketParams.loanToken).forceApprove(C_USDC_V2, supplied);
        require(ICToken(C_USDC_V2).mint(supplied) == 0, "mint error");
        vm.stopPrank();

        uint256 cTokenBalance = ICToken(C_USDC_V2).balanceOf(user);
        supplied = cTokenBalance.wMulDown(ICToken(C_USDC_V2).exchangeRateStored());

        vm.prank(user);
        IERC20(C_USDC_V2).forceApprove(address(Permit2Lib.PERMIT2), cTokenBalance);

        bundle.push(_approve2(privateKey, C_USDC_V2, uint160(cTokenBalance), 0, false));
        bundle.push(_permit2TransferFrom(C_USDC_V2, address(migrationAdapter), cTokenBalance));
        bundle.push(_compoundV2RedeemErc20(C_USDC_V2, cTokenBalance, address(generalAdapter1)));
        bundle.push(_morphoSupply(marketParams, supplied, 0, type(uint256).max, user, hex""));

        vm.prank(user);
        bundler3.multicall(bundle);

        _assertSupplierPosition(supplied, user, address(generalAdapter1));
    }

    function testMigrateSupplierToVaultWithPermit2(uint256 supplied) public onlyEthereum {
        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);
        supplied = bound(supplied, 100, 100 ether);

        deal(marketParams.loanToken, user, supplied);

        vm.startPrank(user);
        IERC20(marketParams.loanToken).forceApprove(C_USDC_V2, supplied);
        require(ICToken(C_USDC_V2).mint(supplied) == 0, "mint error");
        vm.stopPrank();

        uint256 cTokenBalance = ICToken(C_USDC_V2).balanceOf(user);
        supplied = cTokenBalance.wMulDown(ICToken(C_USDC_V2).exchangeRateStored());

        vm.prank(user);
        IERC20(C_USDC_V2).forceApprove(address(Permit2Lib.PERMIT2), cTokenBalance);

        bundle.push(_approve2(privateKey, C_USDC_V2, uint160(cTokenBalance), 0, false));
        bundle.push(_permit2TransferFrom(C_USDC_V2, address(migrationAdapter), cTokenBalance));
        bundle.push(_compoundV2RedeemErc20(C_USDC_V2, cTokenBalance, address(generalAdapter1)));
        bundle.push(_erc4626Deposit(address(suppliersVault), supplied, type(uint256).max, user));

        vm.prank(user);
        bundler3.multicall(bundle);

        _assertVaultSupplierPosition(supplied, user, address(generalAdapter1));
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

    function _compoundV2RedeemErc20(address cToken, uint256 amount, address receiver)
        internal
        view
        returns (Call memory)
    {
        return
            _call(migrationAdapter, abi.encodeCall(migrationAdapter.compoundV2RedeemErc20, (cToken, amount, receiver)));
    }
}
