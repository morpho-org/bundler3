// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IComptroller} from "../../../src/interfaces/IComptroller.sol";

import "../../../src/adapters/migration/CompoundV2MigrationAdapter.sol";

import "./helpers/MigrationForkTest.sol";

contract CompoundV2EthBorrowableMigrationAdapterForkTest is MigrationForkTest {
    using MathLib for uint256;
    using SafeTransferLib for ERC20;
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;

    address internal immutable C_ETH_V2 = getAddress("C_ETH_V2");
    address internal immutable C_DAI_V2 = getAddress("C_DAI_V2");
    address internal immutable COMPTROLLER = getAddress("COMPTROLLER");
    address internal immutable DAI = getAddress("DAI");
    address internal immutable WETH = getAddress("WETH");

    address[] internal enteredMarkets;

    CompoundV2MigrationAdapter internal migrationAdapter;

    receive() external payable {}

    function setUp() public override {
        super.setUp();

        if (block.chainid != 1) return;

        _initMarket(DAI, WETH);

        migrationAdapter = new CompoundV2MigrationAdapter(address(multiexec), C_ETH_V2);

        enteredMarkets.push(C_DAI_V2);
    }

    function testCompoundV2RepayEthZeroAmount() public onlyEthereum {
        bundle.push(_compoundV2RepayEth(0, address(this)));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        multiexec.multicall(bundle);
    }

    function testCompoundV2RepayEthUnauthorized(uint256 amount) public onlyEthereum {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(ErrorsLib.UnauthorizedSender.selector);
        migrationAdapter.compoundV2RepayEth(amount, address(this));
    }

    function testCompoundV2RedeemEth(uint256 amount, address receiver) public onlyEthereum {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(ErrorsLib.UnauthorizedSender.selector);
        migrationAdapter.compoundV2RedeemEth(amount, receiver);
    }

    function testCompoundV2RedeemEthZeroAmount() public onlyEthereum {
        bundle.push(_compoundV2RedeemEth(0, address(this)));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        multiexec.multicall(bundle);
    }

    function testCompoundV2RepayCEthZeroAmount() public onlyEthereum {
        bundle.push(_compoundV2RepayEth(0, address(this)));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        multiexec.multicall(bundle);
    }

    function testCompoundV2RepayEthMax(uint256 borrowed, uint256 repayFactor) public onlyEthereum {
        uint256 collateral = 10_000 ether;
        borrowed = bound(borrowed, 1 ether, 2 ether);
        repayFactor = bound(repayFactor, 0.01 ether, 0.99 ether);
        uint256 toRepay = borrowed.wMulDown(repayFactor);

        deal(DAI, address(this), collateral);

        ERC20(DAI).safeApprove(C_DAI_V2, collateral);
        require(ICToken(C_DAI_V2).mint(collateral) == 0, "mint error");
        require(IComptroller(COMPTROLLER).enterMarkets(enteredMarkets)[0] == 0, "enter market error");
        require(ICEth(C_ETH_V2).borrow(borrowed) == 0, "borrow error");

        bundle.push(_transferNativeToAdapter(payable(migrationAdapter), toRepay));
        bundle.push(_compoundV2RepayEth(type(uint256).max, address(this)));

        multiexec.multicall{value: toRepay}(bundle);
        assertEq(ICEth(C_ETH_V2).borrowBalanceCurrent(address(this)), borrowed - toRepay);
    }

    function testCompoundV2RepayEthNotMax(uint256 borrowed, uint256 repayFactor) public onlyEthereum {
        uint256 collateral = 10_000 ether;
        borrowed = bound(borrowed, 1 ether, 2 ether);
        repayFactor = bound(repayFactor, 0.01 ether, 10 ether);
        uint256 toRepay = borrowed.wMulDown(repayFactor);

        deal(DAI, USER, collateral);

        vm.startPrank(USER);
        ERC20(DAI).safeApprove(C_DAI_V2, collateral);
        require(ICToken(C_DAI_V2).mint(collateral) == 0, "mint error");
        require(IComptroller(COMPTROLLER).enterMarkets(enteredMarkets)[0] == 0, "enter market error");
        require(ICEth(C_ETH_V2).borrow(borrowed) == 0, "borrow error");
        vm.stopPrank();

        deal(address(this), toRepay);
        SafeTransferLib.safeTransferETH(address(migrationAdapter), toRepay);

        bundle.push(_compoundV2RepayEth(toRepay, USER));
        multiexec.multicall(bundle);
        if (repayFactor < 1 ether) {
            assertEq(ICEth(C_ETH_V2).borrowBalanceCurrent(USER), borrowed - toRepay);
        } else {
            assertEq(ICEth(C_ETH_V2).borrowBalanceCurrent(USER), 0);
        }
    }

    function testMigrateBorrowerWithPermit2() public onlyEthereum {
        uint256 collateral = 10_000 ether;
        uint256 borrowed = 1 ether;

        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);

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
        callbackBundle.push(_morphoBorrow(marketParams, borrowed, 0, 0, address(generalAdapter1)));
        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, false, 1, false));
        callbackBundle.push(_unwrapNative(borrowed, address(migrationAdapter)));
        callbackBundle.push(_compoundV2RepayEth(borrowed / 2, user));
        callbackBundle.push(_compoundV2RepayEth(type(uint256).max, user));
        callbackBundle.push(_approve2(privateKey, C_DAI_V2, uint160(cTokenBalance), 0, false));
        callbackBundle.push(_transferFrom2(C_DAI_V2, address(migrationAdapter), cTokenBalance));
        callbackBundle.push(_compoundV2RedeemErc20(C_DAI_V2, cTokenBalance, address(generalAdapter1)));

        bundle.push(_morphoSupplyCollateral(marketParams, collateral, user, abi.encode(callbackBundle)));

        vm.prank(user);
        multiexec.multicall(bundle);

        _assertBorrowerPosition(collateral, borrowed, user, address(generalAdapter1));
    }

    function testMigrateSupplierWithPermit2(uint256 supplied) public onlyEthereum {
        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);
        supplied = bound(supplied, 0.1 ether, 100 ether);

        deal(user, supplied);

        vm.prank(user);
        ICEth(C_ETH_V2).mint{value: supplied}();

        uint256 cTokenBalance = ICEth(C_ETH_V2).balanceOf(user);
        supplied = cTokenBalance.wMulDown(ICToken(C_ETH_V2).exchangeRateStored());

        vm.prank(user);
        ERC20(C_ETH_V2).safeApprove(address(Permit2Lib.PERMIT2), cTokenBalance);

        bundle.push(_approve2(privateKey, C_ETH_V2, uint160(cTokenBalance), 0, false));
        bundle.push(_transferFrom2(C_ETH_V2, address(migrationAdapter), cTokenBalance));
        bundle.push(_compoundV2RedeemEth(cTokenBalance, address(generalAdapter1)));
        bundle.push(_wrapNativeNoFunding(supplied, address(generalAdapter1)));
        bundle.push(_morphoSupply(marketParams, supplied, 0, type(uint256).max, user, hex""));

        vm.prank(user);
        multiexec.multicall(bundle);

        _assertSupplierPosition(supplied, user, address(generalAdapter1));
    }

    function testMigrateSupplierToVaultWithPermit2(uint256 supplied) public onlyEthereum {
        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);
        supplied = bound(supplied, 0.1 ether, 100 ether);

        deal(user, supplied);

        vm.prank(user);
        ICEth(C_ETH_V2).mint{value: supplied}();

        uint256 cTokenBalance = ICEth(C_ETH_V2).balanceOf(user);
        supplied = cTokenBalance.wMulDown(ICToken(C_ETH_V2).exchangeRateStored());

        vm.prank(user);
        ERC20(C_ETH_V2).safeApprove(address(Permit2Lib.PERMIT2), cTokenBalance);

        bundle.push(_approve2(privateKey, C_ETH_V2, uint160(cTokenBalance), 0, false));
        bundle.push(_transferFrom2(C_ETH_V2, address(migrationAdapter), cTokenBalance));
        bundle.push(_compoundV2RedeemEth(cTokenBalance, address(generalAdapter1)));
        bundle.push(_wrapNativeNoFunding(supplied, address(generalAdapter1)));
        bundle.push(_erc4626Deposit(address(suppliersVault), supplied, type(uint256).max, user));

        vm.prank(user);
        multiexec.multicall(bundle);

        _assertVaultSupplierPosition(supplied, user, address(generalAdapter1));
    }

    /* ACTIONS */

    function _compoundV2RepayEth(uint256 repayAmount, address onBehalf) internal view returns (Call memory) {
        return _call(migrationAdapter, abi.encodeCall(migrationAdapter.compoundV2RepayEth, (repayAmount, onBehalf)));
    }

    function _compoundV2RedeemErc20(address cToken, uint256 amount, address receiver)
        internal
        view
        returns (Call memory)
    {
        return
            _call(migrationAdapter, abi.encodeCall(migrationAdapter.compoundV2RedeemErc20, (cToken, amount, receiver)));
    }

    function _compoundV2RedeemEth(uint256 amount, address receiver) internal view returns (Call memory) {
        return _call(migrationAdapter, abi.encodeCall(migrationAdapter.compoundV2RedeemEth, (amount, receiver)));
    }
}
