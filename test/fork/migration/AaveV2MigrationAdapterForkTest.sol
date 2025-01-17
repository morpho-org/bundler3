// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IStEth} from "../../../src/interfaces/IStEth.sol";
import {IAaveV2} from "../../../src/interfaces/IAaveV2.sol";
import {IERC4626} from "../../../lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

import "../../../src/adapters/migration/AaveV2MigrationAdapter.sol";

import "./helpers/MigrationForkTest.sol";

contract AaveV2MigrationAdapterForkTest is MigrationForkTest {
    using SafeERC20 for IERC20;
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;

    address internal immutable AAVE_V2_POOL = getAddress("AAVE_V2_POOL");
    address internal immutable ST_ETH = getAddress("ST_ETH");
    address internal immutable WST_ETH = getAddress("WST_ETH");
    address internal immutable S_DAI = getAddress("S_DAI");
    address internal immutable DAI = getAddress("DAI");
    address internal immutable WETH = getAddress("WETH");

    uint256 internal constant RATE_MODE = 2;

    uint256 internal collateralSupplied = 10_000 ether;
    uint256 internal constant borrowed = 1 ether;

    AaveV2MigrationAdapter internal migrationAdapter;

    function setUp() public override {
        super.setUp();

        if (block.chainid != 1) return;

        _initMarket(DAI, WETH);

        vm.label(AAVE_V2_POOL, "Aave V2 Pool");

        migrationAdapter = new AaveV2MigrationAdapter(address(bundler3), AAVE_V2_POOL);
    }

    function testAaveV2RepayUnauthorized(uint256 amount) public onlyEthereum {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(ErrorsLib.UnauthorizedSender.selector);
        migrationAdapter.aaveV2Repay(marketParams.loanToken, amount, 1, address(this));
    }

    function testAaveV2WithdrawUnauthorized(uint256 amount) public onlyEthereum {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(ErrorsLib.UnauthorizedSender.selector);
        migrationAdapter.aaveV2Withdraw(marketParams.loanToken, amount, address(this));
    }

    function testAaveV2RepayZeroAmount() public onlyEthereum {
        bundle.push(_aaveV2Repay(marketParams.loanToken, 0, address(this)));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        bundler3.multicall(bundle);
    }

    function testAaveV2RepayOnBehalf() public onlyEthereum {
        deal(marketParams.collateralToken, USER, collateralSupplied);

        vm.startPrank(USER);
        IERC20(marketParams.collateralToken).forceApprove(AAVE_V2_POOL, collateralSupplied);
        IAaveV2(AAVE_V2_POOL).deposit(marketParams.collateralToken, collateralSupplied, USER, 0);
        IAaveV2(AAVE_V2_POOL).borrow(marketParams.loanToken, borrowed, RATE_MODE, 0, USER);
        vm.stopPrank();

        deal(marketParams.loanToken, address(migrationAdapter), borrowed);

        (, uint256 debt,,,,) = IAaveV2(AAVE_V2_POOL).getUserAccountData(USER);
        assertGt(debt, 0);

        bundle.push(_aaveV2Repay(marketParams.loanToken, borrowed, USER));
        bundler3.multicall(bundle);

        (, debt,,,,) = IAaveV2(AAVE_V2_POOL).getUserAccountData(USER);
        assertEq(debt, 0);

        assertEq(
            IERC20(marketParams.loanToken).allowance(address(migrationAdapter), address(AAVE_V2_POOL)),
            0,
            "loanToken.allowance(migrationAdapter, AaveV2Pool)"
        );
    }

    function testMigrateBorrowerWithPermit2() public onlyEthereum {
        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);

        _provideLiquidity(borrowed);

        deal(marketParams.collateralToken, user, collateralSupplied);

        vm.startPrank(user);
        IERC20(marketParams.collateralToken).forceApprove(AAVE_V2_POOL, collateralSupplied);
        IAaveV2(AAVE_V2_POOL).deposit(marketParams.collateralToken, collateralSupplied, user, 0);
        IAaveV2(AAVE_V2_POOL).borrow(marketParams.loanToken, borrowed, RATE_MODE, 0, user);
        vm.stopPrank();

        address aToken = _getATokenV2(marketParams.collateralToken);
        uint256 aTokenBalance = IERC20(aToken).balanceOf(user);

        vm.prank(user);
        IERC20(aToken).forceApprove(address(Permit2Lib.PERMIT2), aTokenBalance);

        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));
        callbackBundle.push(_morphoBorrow(marketParams, borrowed, 0, 0, address(migrationAdapter)));
        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, false, 1, false));
        callbackBundle.push(_aaveV2Repay(marketParams.loanToken, borrowed / 2, user));
        callbackBundle.push(_aaveV2Repay(marketParams.loanToken, type(uint256).max, user));
        callbackBundle.push(_approve2(privateKey, aToken, uint160(aTokenBalance), 0, false));
        callbackBundle.push(_permit2TransferFrom(aToken, address(migrationAdapter), aTokenBalance));
        callbackBundle.push(_aaveV2Withdraw(marketParams.collateralToken, collateralSupplied, address(generalAdapter1)));

        bundle.push(_morphoSupplyCollateral(marketParams, collateralSupplied, user, abi.encode(callbackBundle)));

        vm.prank(user);
        bundler3.multicall(bundle);

        _assertBorrowerPosition(collateralSupplied, borrowed, user, address(generalAdapter1));
    }

    function testMigrateBorrowerDaiToSDaiWithPermit2() public onlyEthereum {
        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);

        _initMarket(S_DAI, WETH);
        _provideLiquidity(borrowed);

        deal(DAI, user, collateralSupplied);

        vm.startPrank(user);
        IERC20(DAI).forceApprove(AAVE_V2_POOL, collateralSupplied);
        IAaveV2(AAVE_V2_POOL).deposit(DAI, collateralSupplied, user, 0);
        IAaveV2(AAVE_V2_POOL).borrow(marketParams.loanToken, borrowed, RATE_MODE, 0, user);
        vm.stopPrank();

        address aToken = _getATokenV2(DAI);
        uint256 aTokenBalance = IERC20(aToken).balanceOf(user);

        vm.prank(user);
        IERC20(aToken).forceApprove(address(Permit2Lib.PERMIT2), aTokenBalance);

        uint256 sDaiAmount = IERC4626(S_DAI).previewDeposit(collateralSupplied);

        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));
        callbackBundle.push(_morphoBorrow(marketParams, borrowed, 0, 0, address(migrationAdapter)));
        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, false, 1, false));
        callbackBundle.push(_aaveV2Repay(marketParams.loanToken, borrowed / 2, user));
        callbackBundle.push(_aaveV2Repay(marketParams.loanToken, type(uint256).max, user));
        callbackBundle.push(_approve2(privateKey, aToken, uint160(aTokenBalance), 0, false));
        callbackBundle.push(_permit2TransferFrom(aToken, address(migrationAdapter), aTokenBalance));
        callbackBundle.push(_aaveV2Withdraw(DAI, collateralSupplied, address(generalAdapter1)));
        callbackBundle.push(_erc4626Deposit(S_DAI, collateralSupplied, type(uint256).max, address(generalAdapter1)));

        bundle.push(_morphoSupplyCollateral(marketParams, sDaiAmount, user, abi.encode(callbackBundle)));

        vm.prank(user);
        bundler3.multicall(bundle);

        _assertBorrowerPosition(sDaiAmount, borrowed, user, address(generalAdapter1));
    }

    function testMigrateStEthPositionWithPermit2() public onlyEthereum {
        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);

        _initMarket(WST_ETH, marketParams.loanToken);
        _provideLiquidity(borrowed);

        deal(ST_ETH, user, collateralSupplied);

        collateralSupplied = IERC20(ST_ETH).balanceOf(user);

        vm.startPrank(user);
        IERC20(ST_ETH).forceApprove(AAVE_V2_POOL, collateralSupplied);
        IAaveV2(AAVE_V2_POOL).deposit(ST_ETH, collateralSupplied, user, 0);
        IAaveV2(AAVE_V2_POOL).borrow(marketParams.loanToken, borrowed, RATE_MODE, 0, user);
        vm.stopPrank();

        // The amount of stEth as collateral is decreased by 10 beceause of roundings.
        collateralSupplied -= 10;

        address aToken = _getATokenV2(ST_ETH);
        uint256 aTokenBalance = IERC20(aToken).balanceOf(user);

        uint256 wstEthAmount = IStEth(ST_ETH).getSharesByPooledEth(collateralSupplied);

        vm.prank(user);
        IERC20(aToken).forceApprove(address(Permit2Lib.PERMIT2), aTokenBalance);

        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, true, 0, false));
        callbackBundle.push(_morphoBorrow(marketParams, borrowed, 0, 0, address(migrationAdapter)));
        callbackBundle.push(_morphoSetAuthorizationWithSig(privateKey, false, 1, false));
        callbackBundle.push(_aaveV2Repay(marketParams.loanToken, borrowed / 2, user));
        callbackBundle.push(_aaveV2Repay(marketParams.loanToken, type(uint256).max, user));
        callbackBundle.push(_approve2(privateKey, aToken, type(uint160).max, 0, false));
        callbackBundle.push(_permit2TransferFrom(aToken, address(migrationAdapter), aTokenBalance));
        callbackBundle.push(_aaveV2Withdraw(ST_ETH, type(uint256).max, address(ethereumGeneralAdapter1)));
        callbackBundle.push(_wrapStEth(type(uint256).max, address(generalAdapter1)));

        bundle.push(_morphoSupplyCollateral(marketParams, wstEthAmount, user, abi.encode(callbackBundle)));

        vm.prank(user);
        bundler3.multicall(bundle);

        _assertBorrowerPosition(wstEthAmount, borrowed, user, address(generalAdapter1));
    }

    function testMigrateSupplierWithPermit2(uint256 supplied) public onlyEthereum {
        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);
        supplied = bound(supplied, 100, 100 ether);

        deal(marketParams.loanToken, user, supplied + 1);

        vm.startPrank(user);
        IERC20(marketParams.loanToken).forceApprove(AAVE_V2_POOL, supplied + 1);
        IAaveV2(AAVE_V2_POOL).deposit(marketParams.loanToken, supplied + 1, user, 0);
        vm.stopPrank();

        address aToken = _getATokenV2(marketParams.loanToken);
        uint256 aTokenBalance = IERC20(aToken).balanceOf(user);

        vm.prank(user);
        IERC20(aToken).forceApprove(address(Permit2Lib.PERMIT2), aTokenBalance);

        bundle.push(_approve2(privateKey, aToken, uint160(aTokenBalance), 0, false));
        bundle.push(_permit2TransferFrom(aToken, address(migrationAdapter), aTokenBalance));
        bundle.push(_aaveV2Withdraw(marketParams.loanToken, supplied, address(generalAdapter1)));
        bundle.push(_morphoSupply(marketParams, supplied, 0, type(uint256).max, user, hex""));

        vm.prank(user);
        bundler3.multicall(bundle);

        _assertSupplierPosition(supplied, user, address(generalAdapter1));
    }

    function testMigrateSupplierToVaultWithPermit2(uint256 supplied) public onlyEthereum {
        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);
        supplied = bound(supplied, 100, 100 ether);

        deal(marketParams.loanToken, user, supplied + 1);

        vm.startPrank(user);
        IERC20(marketParams.loanToken).forceApprove(AAVE_V2_POOL, supplied + 1);
        IAaveV2(AAVE_V2_POOL).deposit(marketParams.loanToken, supplied + 1, user, 0);
        vm.stopPrank();

        address aToken = _getATokenV2(marketParams.loanToken);
        uint256 aTokenBalance = IERC20(aToken).balanceOf(user);

        vm.prank(user);
        IERC20(aToken).forceApprove(address(Permit2Lib.PERMIT2), aTokenBalance);

        bundle.push(_approve2(privateKey, aToken, uint160(aTokenBalance), 0, false));
        bundle.push(_permit2TransferFrom(aToken, address(migrationAdapter), aTokenBalance));
        bundle.push(_aaveV2Withdraw(marketParams.loanToken, supplied, address(generalAdapter1)));
        bundle.push(_erc4626Deposit(address(suppliersVault), supplied, type(uint256).max, user));

        vm.prank(user);
        bundler3.multicall(bundle);

        _assertVaultSupplierPosition(supplied, user, address(generalAdapter1));
    }

    function _getATokenV2(address asset) internal view returns (address) {
        return IAaveV2(AAVE_V2_POOL).getReserveData(asset).aTokenAddress;
    }

    /* ACTIONS */

    function _aaveV2Repay(address token, uint256 amount, address onBehalf) internal view returns (Call memory) {
        return
            _call(migrationAdapter, abi.encodeCall(migrationAdapter.aaveV2Repay, (token, amount, RATE_MODE, onBehalf)));
    }

    function _aaveV2Withdraw(address token, uint256 amount, address receiver) internal view returns (Call memory) {
        return _call(migrationAdapter, abi.encodeCall(migrationAdapter.aaveV2Withdraw, (token, amount, receiver)));
    }
}
