// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";

import "./helpers/LocalTest.sol";
import {IAugustusRegistry} from "../../src/interfaces/IAugustusRegistry.sol";
import {MathLib} from "../../lib/morpho-blue/src/libraries/MathLib.sol";

contract AugustusRegistryMock is IAugustusRegistry {
    mapping(address => bool) valids;

    function setValid(address account, bool isValid) external {
        valids[account] = isValid;
    }

    function isValidAugustus(address account) external view returns (bool) {
        return valids[account];
    }
}

contract AugustusMock {
    function mockBuy(address srcToken, address destToken, uint256 toAmount) external {
        uint256 fromAmount = toAmount;
        ERC20(srcToken).transferFrom(msg.sender, address(this), fromAmount);
        ERC20Mock(destToken).setBalance(address(this), toAmount);
        ERC20(destToken).transfer(msg.sender, toAmount);
    }

    function mockSell(address srcToken, address destToken, uint256 fromAmount) external {
        uint256 toAmount = fromAmount;
        ERC20(srcToken).transferFrom(msg.sender, address(this), fromAmount);
        ERC20Mock(destToken).setBalance(address(this), toAmount);
        ERC20(destToken).transfer(msg.sender, toAmount);
    }
}

contract ParaswapModuleTest is LocalTest {
    using MarketParamsLib for MarketParams;
    using MorphoBalancesLib for IMorpho;
    using MorphoLib for IMorpho;
    using MathLib for uint256;

    ParaswapModule paraswapModule;
    AugustusRegistryMock augustusRegistry;
    AugustusMock augustus;

    ERC20Mock collateralToken2;
    MarketParams internal marketParamsCollateral2;
    Id internal idCollateral2;

    ERC20Mock loanToken2;
    MarketParams internal marketParamsLoan2;
    Id internal idLoan2;

    MarketParams internal emptyMarketParams;

    // If ratio too close to 100%:
    // - debt accruals between bundle creation and tx may trigger a revert
    // - asset.toShares may overestimate share amount and trigger a revert
    //
    // If ratio too close to 0:
    // - final amount may be 0
    uint256 internal MIN_RATIO = WAD / 100;
    uint256 internal MAX_RATIO = 99 * WAD / 100;

    function setUp() public virtual override {
        super.setUp();
        augustusRegistry = new AugustusRegistryMock();
        augustus = new AugustusMock();
        augustusRegistry.setValid(address(augustus), true);
        paraswapModule = new ParaswapModule(address(bundler), address(augustusRegistry));

        // New loan token

        loanToken2 = new ERC20Mock("loan2", "B2");
        vm.label(address(loanToken2), "loanToken2");
        marketParamsLoan2 =
            MarketParams(address(loanToken2), address(collateralToken), address(oracle), address(irm), LLTV);
        idLoan2 = marketParamsLoan2.id();

        vm.prank(OWNER);
        morpho.createMarket(marketParamsLoan2);

        vm.startPrank(SUPPLIER);
        loanToken2.approve(address(morpho), type(uint256).max);
        loanToken.approve(address(morpho), type(uint256).max);

        vm.startPrank(USER);
        morpho.setAuthorization(address(bundler), true);
        collateralToken.approve(address(morpho), type(uint256).max);
        loanToken.approve(address(morpho), type(uint256).max);
        vm.stopPrank();

        // New collateral token

        collateralToken2 = new ERC20Mock("collateral2", "C2");
        vm.label(address(collateralToken2), "collateralToken2");
        marketParamsCollateral2 =
            MarketParams(address(loanToken), address(collateralToken2), address(oracle), address(irm), LLTV);
        idCollateral2 = marketParamsCollateral2.id();

        vm.prank(OWNER);
        morpho.createMarket(marketParamsCollateral2);
    }

    function _sell(
        address srcToken,
        address destToken,
        uint256 sellAmount,
        uint256 minBuyAmount,
        bool sellEntireBalance,
        address receiver
    ) internal view returns (bytes memory) {
        return _moduleCall(
            address(paraswapModule),
            _paraswapSell(
                address(augustus),
                abi.encodeCall(augustus.mockSell, (srcToken, destToken, sellAmount)),
                srcToken,
                destToken,
                minBuyAmount,
                sellEntireBalance,
                4 + 32 + 32, // sig + 2 values
                receiver
            )
        );
    }

    function _buy(
        address srcToken,
        address destToken,
        uint256 maxSellAmount,
        uint256 buyAmount,
        MarketParams memory marketParams,
        address receiver
    ) internal view returns (bytes memory) {
        return _moduleCall(
            address(paraswapModule),
            _paraswapBuy(
                address(augustus),
                abi.encodeCall(augustus.mockBuy, (srcToken, destToken, buyAmount)),
                srcToken,
                destToken,
                maxSellAmount,
                marketParams,
                4 + 32 + 32, // sig + 2 values
                receiver
            )
        );
    }

    function _callable(address account) internal {
        assumeNotPrecompile(account);
        assumeNotZeroAddress(account);
        vm.assume(account != 0x000000000000000000000000000000000000000A);
        vm.assume(account.code.length == 0);
        vm.etch(account, hex"5f5ff3"); // always return null
    }

    function _receiver(address account) internal view {
        assumeNotZeroAddress(account);
        vm.assume(account != address(morpho));
        vm.assume(account != address(paraswapModule));
    }

    function testAugustusInRegistrySellCheck(address _augustus) public {
        augustusRegistry.setValid(_augustus, false);

        vm.prank(address(bundler));

        vm.expectRevert(bytes(ErrorsLib.AUGUSTUS_NOT_IN_REGISTRY));
        paraswapModule.sell(_augustus, hex"", address(0), address(0), 0, true, 0, address(0));
    }

    function testAugustusInRegistryBuyCheck(address _augustus) public {
        augustusRegistry.setValid(_augustus, false);

        vm.prank(address(bundler));

        MarketParams memory marketParams;
        vm.expectRevert(bytes(ErrorsLib.AUGUSTUS_NOT_IN_REGISTRY));
        paraswapModule.buy(_augustus, hex"", address(0), address(0), 0, marketParams, 0, address(0));
    }

    function testBytesAtOffsetLengthCheckSell(uint256 length, uint256 offset) public {
        length = bound(length, 32, 1024);
        offset = bound(offset, length - 32 + 1, type(uint256).max);
        vm.expectRevert(bytes(ErrorsLib.INVALID_OFFSET));
        bundle.push(
            _moduleCall(
                address(paraswapModule),
                _paraswapSell(
                    address(augustus),
                    new bytes(length),
                    address(collateralToken),
                    address(loanToken),
                    type(uint256).max,
                    true,
                    offset,
                    address(1)
                )
            )
        );
        bundler.multicall(bundle);
    }

    function testBytesAtOffsetLengthCheckBuy(uint256 length, uint256 offset) public {
        length = bound(length, 32, 1024);
        offset = bound(offset, length - 32 + 1, type(uint256).max);
        vm.expectRevert(bytes(ErrorsLib.INVALID_OFFSET));
        bundle.push(
            _moduleCall(
                address(paraswapModule),
                _paraswapBuy(
                    address(augustus),
                    new bytes(length),
                    address(collateralToken),
                    address(loanToken),
                    type(uint256).max,
                    marketParams,
                    offset,
                    address(1)
                )
            )
        );
        bundler.multicall(bundle);
    }

    function testWriteBytesAtOffsetSell(address _augustus, uint256 balance, uint256 offset) public {
        _callable(_augustus);
        augustusRegistry.setValid(_augustus, true);
        uint256 callDataLength = 1024;

        balance = bound(balance, 1, type(uint120).max);
        offset = bound(offset, 0, callDataLength - 32);
        collateralToken.setBalance(address(paraswapModule), balance);

        bytes memory callData =
            bytes.concat(new bytes(offset), bytes32(uint256(balance)), new bytes(callDataLength - 32 - offset));

        vm.expectCall(address(_augustus), callData);

        bundle.push(
            _moduleCall(
                address(paraswapModule),
                _paraswapSell(
                    _augustus, callData, address(collateralToken), address(loanToken), 0, true, offset, address(1)
                )
            )
        );
        bundler.multicall(bundle);
    }

    function testwriteBytesAtOffsetBuy(address _augustus, uint256 debt, uint256 offset) public {
        debt = bound(debt, 1, type(uint104).max);
        _callable(_augustus);
        augustusRegistry.setValid(_augustus, true);
        uint256 callDataLength = 1024;

        _supplyCollateral(marketParams, debt * 2, address(this));
        _supply(marketParams, debt * 2, address(this));
        _borrow(marketParams, debt, address(this));

        offset = bound(offset, 0, callDataLength - 32);
        bytes memory callData =
            bytes.concat(new bytes(offset), bytes32(uint256(debt)), new bytes(callDataLength - 32 - offset));

        vm.expectCall(address(_augustus), callData);

        bundle.push(
            _moduleCall(
                address(paraswapModule),
                _paraswapBuy(
                    _augustus,
                    callData,
                    address(collateralToken),
                    address(loanToken),
                    1,
                    marketParams,
                    offset,
                    address(1)
                )
            )
        );
        bundler.multicall(bundle);
    }

    function testIncorrectLoanToken(address argToken, address marketToken) public {
        vm.assume(marketToken != address(0));
        vm.assume(argToken != marketToken);

        marketParams.loanToken = marketToken;

        vm.expectRevert(bytes(ErrorsLib.INCORRECT_LOAN_TOKEN));
        vm.prank(address(bundler));
        paraswapModule.buy(
            address(augustus), new bytes(32), address(collateralToken), argToken, 0, marketParams, 0, address(0)
        );
    }

    function testSellSlippageCheckNoAdjustment(uint256 sellAmount, uint256 adjust) public {
        sellAmount = bound(sellAmount, 1, type(uint128).max);
        adjust = bound(adjust, 1, type(uint128).max);
        uint256 minBuyAmount = sellAmount + adjust;

        collateralToken.setBalance(address(paraswapModule), sellAmount);

        vm.expectRevert(bytes(ErrorsLib.SLIPPAGE_EXCEEDED));
        bundle.push(_sell(address(collateralToken), address(loanToken), sellAmount, minBuyAmount, false, address(this)));
        bundler.multicall(bundle);
    }

    function testBuySlippageCheckNoAdjustment(uint256 buyAmount, uint256 adjust) public {
        buyAmount = bound(buyAmount, 1, type(uint128).max);
        adjust = bound(adjust, 1, buyAmount);
        uint256 maxSellAmount = buyAmount - adjust;

        collateralToken.setBalance(address(paraswapModule), buyAmount); // price is 1

        vm.expectRevert(bytes(ErrorsLib.SLIPPAGE_EXCEEDED));
        bundle.push(
            _buy(
                address(collateralToken), address(loanToken), maxSellAmount, buyAmount, emptyMarketParams, address(this)
            )
        );
        bundler.multicall(bundle);
    }

    function testSellSlippageCheckWithAdjustment(uint256 sellAmount, uint256 adjust, uint256 percent) public {
        percent = bound(percent, 1, 1000);
        sellAmount = bound(sellAmount, 1, type(uint120).max);
        adjust = bound(adjust, 1, sellAmount);
        uint256 minBuyAmount = sellAmount + adjust;

        collateralToken.setBalance(address(paraswapModule), sellAmount.mulDivUp(percent, 100));

        vm.expectRevert(bytes(ErrorsLib.SLIPPAGE_EXCEEDED));
        bundle.push(_sell(address(collateralToken), address(loanToken), sellAmount, minBuyAmount, true, address(this)));
        bundler.multicall(bundle);
    }

    function testX() public {
        testSellSlippageCheckWithAdjustment(
            91963739657892556963730456531714190049907408351194895,
            24454938018736622817597843437438855705529675740,
            98347530794108903447367692402
        );
    }

    function testBuySlippageCheckWithAdjustment(uint256 buyAmount, uint256 adjust, uint256 percent) public {
        percent = bound(percent, 1, 1000);
        buyAmount = bound(buyAmount, 1, type(uint64).max);
        adjust = bound(adjust, 1, buyAmount);
        uint256 maxSellAmount = buyAmount - adjust;
        uint256 debt = buyAmount.mulDivUp(percent, 100);

        _supplyCollateral(marketParams, type(uint104).max, address(this));
        _supply(marketParams, type(uint104).max, address(this));
        _borrow(marketParams, debt, address(this));
        collateralToken.setBalance(address(paraswapModule), type(uint128).max);

        vm.expectRevert(bytes(ErrorsLib.SLIPPAGE_EXCEEDED));
        bundle.push(
            _buy(address(collateralToken), address(loanToken), maxSellAmount, buyAmount, marketParams, address(this))
        );
        bundler.multicall(bundle);
    }

    function testSellNoAdjustment(uint256 amount, uint256 extra, address receiver) public {
        _receiver(receiver);

        amount = bound(amount, 1, type(uint128).max);
        extra = bound(extra, 0, type(uint128).max);

        collateralToken.setBalance(address(paraswapModule), amount + extra);
        bundle.push(_sell(address(collateralToken), address(loanToken), amount, amount, false, receiver));
        bundler.multicall(bundle);
        assertEq(collateralToken.balanceOf(receiver), extra, "receiver collateral");
        assertEq(loanToken.balanceOf(receiver), amount, "receiver loan token");
        assertEq(collateralToken.balanceOf(address(paraswapModule)), 0, "module collateral");
        assertEq(loanToken.balanceOf(address(paraswapModule)), 0, "module loan token");
    }

    function testBuyNoAdjustment(uint256 amount, uint256 extra, address receiver) public {
        _receiver(receiver);

        amount = bound(amount, 1, type(uint128).max);
        extra = bound(extra, 0, type(uint128).max);

        collateralToken.setBalance(address(paraswapModule), amount + extra);
        bundle.push(_buy(address(collateralToken), address(loanToken), amount, amount, emptyMarketParams, receiver));
        bundler.multicall(bundle);
        assertEq(collateralToken.balanceOf(receiver), extra, "receiver collateral");
        assertEq(loanToken.balanceOf(receiver), amount, "receiver loan token");
        assertEq(collateralToken.balanceOf(address(paraswapModule)), 0, "module collateral");
        assertEq(loanToken.balanceOf(address(paraswapModule)), 0, "module loan token");
    }

    function testSellWithAdjustment(uint256 sellAmount, uint256 percent, address receiver) public {
        _receiver(receiver);

        percent = bound(percent, 1, 1000);
        sellAmount = bound(sellAmount, 1, type(uint120).max);
        uint256 actualSellAmount = sellAmount.mulDivUp(percent, 100);

        collateralToken.setBalance(address(paraswapModule), actualSellAmount);
        bundle.push(_sell(address(collateralToken), address(loanToken), sellAmount, sellAmount, true, receiver));
        bundler.multicall(bundle);
        assertEq(collateralToken.balanceOf(receiver), 0, "receiver collateral");
        assertEq(loanToken.balanceOf(receiver), actualSellAmount, "receiver loan token");
        assertEq(collateralToken.balanceOf(address(paraswapModule)), 0, "module collateral");
        assertEq(loanToken.balanceOf(address(paraswapModule)), 0, "module loan token");
    }

    function testBuyWithAdjustment(uint256 buyAmount, uint256 percent, address receiver) public {
        _receiver(receiver);

        percent = bound(percent, 1, 1000);
        buyAmount = bound(buyAmount, 1, type(uint64).max);
        uint256 actualBuyAmount = buyAmount.mulDivUp(percent, 100);

        _supplyCollateral(marketParams, type(uint104).max, address(this));
        _supply(marketParams, type(uint104).max, address(this));
        _borrow(marketParams, actualBuyAmount, address(this));
        collateralToken.setBalance(address(paraswapModule), actualBuyAmount);

        bundle.push(_buy(address(collateralToken), address(loanToken), buyAmount, buyAmount, marketParams, receiver));
        bundler.multicall(bundle);
        assertEq(collateralToken.balanceOf(receiver), 0, "receiver collateral");
        assertEq(loanToken.balanceOf(receiver), actualBuyAmount, "receiver loan token");
        assertEq(collateralToken.balanceOf(address(paraswapModule)), 0, "module collateral");
        assertEq(loanToken.balanceOf(address(paraswapModule)), 0, "module loan token");
    }

    function testApprovalResetSell(uint256 amount) public {
        collateralToken.setBalance(address(paraswapModule), amount);
        bundle.push(_sell(address(collateralToken), address(loanToken), amount, amount, false, address(this)));
        bundler.multicall(bundle);
        assertEq(collateralToken.allowance(address(paraswapModule), address(augustus)), 0);
    }

    function testApprovalResetBuy(uint256 amount) public {
        collateralToken.setBalance(address(paraswapModule), amount);
        bundle.push(
            _buy(address(collateralToken), address(loanToken), amount, amount, emptyMarketParams, address(this))
        );
        bundler.multicall(bundle);
        assertEq(collateralToken.allowance(address(paraswapModule), address(augustus)), 0);
    }

    /* WITHDRAW COLLATERAL AND SWAP */

    function testWithdrawCollateralAndSwap(uint256 collateralAmount, uint256 ratio) public {
        collateralAmount = bound(collateralAmount, MIN_AMOUNT, MAX_AMOUNT);

        _supplyCollateral(marketParams, collateralAmount, USER);

        ratio = bound(ratio, MIN_RATIO, WAD);
        uint256 sellAmount = collateralAmount * ratio / WAD;
        _createWithdrawCollateralAndSwapBundle(marketParams, address(collateralToken2), sellAmount, USER);

        skip(2 days);

        vm.prank(USER);
        bundler.multicall(bundle);

        assertEq(morpho.collateral(marketParams.id(), USER), collateralAmount - sellAmount, "sold");
        assertEq(collateralToken2.balanceOf(USER), sellAmount, "bought"); // price is 1
    }

    // Method: withdraw X or all, sell exact amount
    // Works for both partial & full
    function _createWithdrawCollateralAndSwapBundle(
        MarketParams memory marketParams,
        address buyToken,
        uint256 sellAmount,
        address receiver
    ) internal {
        bundle.push(_morphoWithdrawCollateral(marketParams, sellAmount, address(paraswapModule)));
        bundle.push(_sell(marketParams.collateralToken, buyToken, sellAmount, sellAmount, false, receiver));
    }

    /* WITHDRAW AND SWAP */

    function testPartialWithdrawAndSwap(uint256 supplyAmount, uint256 ratio) public {
        supplyAmount = bound(supplyAmount, MIN_AMOUNT, MAX_AMOUNT);

        _supply(marketParams, supplyAmount, USER);

        ratio = bound(ratio, MIN_RATIO, MAX_RATIO);
        uint256 sellAmount = supplyAmount * ratio / WAD;
        _createPartialWithdrawAndSwapBundle(marketParams, address(loanToken2), sellAmount, USER);

        skip(2 days);

        vm.prank(USER);
        bundler.multicall(bundle);

        assertEq(morpho.expectedSupplyAssets(marketParams, USER), supplyAmount - sellAmount, "sold");
        assertEq(loanToken2.balanceOf(USER), sellAmount, "bought"); // price is 1
    }

    // Method: withdraw X, sell exact amount
    function _createPartialWithdrawAndSwapBundle(
        MarketParams memory marketParams,
        address buyToken,
        uint256 assetsToWithdraw,
        address receiver
    ) internal {
        bundle.push(_morphoWithdraw(marketParams, assetsToWithdraw, 0, type(uint256).max, address(paraswapModule)));
        bundle.push(_sell(marketParams.loanToken, buyToken, assetsToWithdraw, assetsToWithdraw, false, receiver));
    }

    function testFullWithdrawAndSwap(uint256 supplyAmount) public {
        supplyAmount = bound(supplyAmount, MIN_AMOUNT, MAX_AMOUNT);

        _supply(marketParams, supplyAmount, USER);

        _createFullWithdrawAndSwapBundle(USER, marketParams, address(loanToken2), USER);

        skip(2 days);

        vm.prank(USER);
        bundler.multicall(bundle);

        assertEq(morpho.expectedSupplyAssets(marketParams, USER), 0, "sold");
        assertEq(loanToken2.balanceOf(USER), supplyAmount, "bought");
    }

    // Method: withdraw all, sell exact amount (replaced by current balance by paraswap module)
    function _createFullWithdrawAndSwapBundle(
        address user,
        MarketParams memory marketParams,
        address buyToken,
        address receiver
    ) internal {
        uint256 sharesToWithdraw = morpho.supplyShares(marketParams.id(), user);
        uint256 currentAssets = morpho.expectedSupplyAssets(marketParams, user);
        bundle.push(_morphoWithdraw(marketParams, 0, sharesToWithdraw, 0, address(paraswapModule)));
        // Sell amount will be adjusted inside the paraswap module to the current balance
        bundle.push(_sell(marketParams.loanToken, buyToken, currentAssets, currentAssets, true, receiver));
    }

    /* SUPPLY SWAP */

    function testPartialSupplySwap(uint256 supplyAmount, uint256 ratio) public {
        supplyAmount = bound(supplyAmount, MIN_AMOUNT, MAX_AMOUNT);

        _supply(marketParams, supplyAmount, USER);

        ratio = bound(ratio, MIN_RATIO, MAX_RATIO);
        uint256 sellAmount = supplyAmount * ratio / WAD;
        _createPartialSupplySwapBundle(USER, marketParams, marketParamsLoan2, address(loanToken2), sellAmount);

        skip(2 days);

        vm.prank(USER);
        bundler.multicall(bundle);

        assertEq(morpho.expectedSupplyAssets(marketParams, USER), supplyAmount - sellAmount, "withdrawn");
        assertEq(morpho.expectedSupplyAssets(marketParamsLoan2, USER), sellAmount, "supplied");
    }

    // Method: withdraw X, sell exact amount, supply all
    function _createPartialSupplySwapBundle(
        address user,
        MarketParams memory sourceParams,
        MarketParams memory destParams,
        address buyToken,
        uint256 assetsToWithdraw
    ) internal {
        _createPartialWithdrawAndSwapBundle(sourceParams, buyToken, assetsToWithdraw, address(bundler));
        bundle.push(_morphoSupply(destParams, type(uint256).max, 0, 0, user, hex""));
    }

    function testFullSupplySwap(uint256 supplyAmount) public {
        supplyAmount = bound(supplyAmount, MIN_AMOUNT, MAX_AMOUNT);

        _supply(marketParams, supplyAmount, USER);

        _createFullSupplySwapBundle(USER, marketParams, marketParamsLoan2, address(loanToken2));

        skip(2 days);

        vm.prank(USER);
        bundler.multicall(bundle);

        assertEq(morpho.expectedSupplyAssets(marketParams, USER), 0, "withdrawn");
        assertEq(morpho.expectedSupplyAssets(marketParamsLoan2, USER), supplyAmount, "supplied");
    }

    // Method: withdraw all, sell all, supply all
    function _createFullSupplySwapBundle(
        address user,
        MarketParams memory sourceParams,
        MarketParams memory destParams,
        address buyToken
    ) internal {
        _createFullWithdrawAndSwapBundle(user, sourceParams, buyToken, address(bundler));
        bundle.push(_morphoSupply(destParams, type(uint256).max, 0, 0, user, hex""));
    }

    /* COLLATERAL SWAP */

    function testPartialCollateralSwap(uint256 borrowAmount, uint256 ratio) public {
        borrowAmount = bound(borrowAmount, MIN_AMOUNT, MAX_AMOUNT);
        uint256 collateralAmount = borrowAmount * 2;

        _supplyCollateral(marketParams, collateralAmount, SUPPLIER); // Need extra collateral for flashloan
        _supply(marketParams, borrowAmount, SUPPLIER);
        _supply(marketParamsCollateral2, borrowAmount, SUPPLIER);
        _supplyCollateral(marketParams, collateralAmount, USER);
        _borrow(marketParams, borrowAmount, USER);

        loanToken.setBalance(USER, 0);

        ratio = bound(ratio, MIN_RATIO, MAX_RATIO);
        uint256 borrowAssetsToTransfer = borrowAmount * ratio / WAD;
        uint256 collateralToSwap = collateralAmount * ratio / WAD;
        _createPartialCollateralSwapBundle(
            USER, marketParams, marketParamsCollateral2, collateralToSwap, borrowAssetsToTransfer
        );

        skip(0.1 days);

        uint256 borrowAssetsBefore = morpho.expectedBorrowAssets(marketParams, USER);

        vm.prank(USER);
        bundler.multicall(bundle);

        assertEq(morpho.collateral(marketParams.id(), USER), collateralAmount - collateralToSwap, "collateral 1");
        assertEq(morpho.collateral(marketParamsCollateral2.id(), USER), collateralToSwap, "collateral 2");
        assertEq(morpho.expectedBorrowAssets(marketParams, USER), borrowAssetsBefore - borrowAssetsToTransfer, "loan 1");
        assertEq(morpho.expectedBorrowAssets(marketParamsCollateral2, USER), borrowAssetsToTransfer, "loan 2");
    }

    // Method: repay, withdraw collateral, sell exact collateral, supply collateral, borrow.
    // Sell amount will be adjusted.
    function _createPartialCollateralSwapBundle(
        address user,
        MarketParams memory sourceParams,
        MarketParams memory destParams,
        uint256 collateralToSwap,
        uint256 borrowAssetsToTransfer
    ) internal {
        callbackBundle.push(_morphoWithdrawCollateral(sourceParams, collateralToSwap, address(paraswapModule)));
        callbackBundle.push(
            _sell(
                sourceParams.collateralToken,
                destParams.collateralToken,
                collateralToSwap,
                collateralToSwap,
                false,
                address(bundler)
            )
        );
        callbackBundle.push(_morphoSupplyCollateral(destParams, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoBorrow(destParams, borrowAssetsToTransfer, 0, type(uint256).max, address(bundler)));
        bundle.push(_morphoRepay(sourceParams, borrowAssetsToTransfer, 0, 0, user));
    }

    function testFullCollateralSwap(uint256 borrowAmount) public {
        borrowAmount = bound(borrowAmount, MIN_AMOUNT, MAX_AMOUNT);
        uint256 collateralAmount = borrowAmount * 2;

        _supplyCollateral(marketParams, collateralAmount, SUPPLIER); // Need extra collateral for flashloan
        _supply(marketParams, borrowAmount, SUPPLIER);
        _supply(marketParamsCollateral2, borrowAmount * 2, SUPPLIER);
        _supplyCollateral(marketParams, collateralAmount, USER);
        _borrow(marketParams, borrowAmount, address(USER));

        loanToken.setBalance(USER, 0);

        _createFullCollateralSwapBundle(USER, marketParams, marketParamsCollateral2);

        skip(2 days);

        uint256 expectedDebt = morpho.expectedBorrowAssets(marketParams, USER);

        vm.prank(USER);
        bundler.multicall(bundle);

        assertEq(morpho.collateral(marketParams.id(), USER), 0);
        assertEq(morpho.collateral(marketParamsCollateral2.id(), USER), collateralAmount);
        assertEq(morpho.expectedBorrowAssets(marketParams, USER), 0);
        assertEq(morpho.expectedBorrowAssets(marketParamsCollateral2, USER), expectedDebt);
    }

    // Method: flashloan, sell exact collateral, supply collateral, copy debt, repay debt, withdraw collateral
    // Limitation: fails if Morpho does not hold 2 * collateral to swap
    // Alternative: repay, withdrawCollateral, swap, supplyCollateral,
    // borrowAmountFromMarketShares(market2,market1,shares+N)
    // Limitations: N required (repay lowers share price) & must be determined, last borrow can revert because +N made
    // user liquidatable
    function _createFullCollateralSwapBundle(
        address user,
        MarketParams memory sourceParams,
        MarketParams memory destParams
    ) internal {
        uint256 borrowShares = morpho.borrowShares(marketParams.id(), user);
        uint256 collateralToSwap = morpho.collateral(marketParams.id(), user);

        callbackBundle.push(_erc20Transfer(sourceParams.collateralToken, address(paraswapModule), collateralToSwap));
        callbackBundle.push(
            _sell(
                sourceParams.collateralToken,
                destParams.collateralToken,
                collateralToSwap,
                collateralToSwap,
                true,
                address(bundler)
            )
        );
        callbackBundle.push(_morphoSupplyCollateral(destParams, type(uint256).max, user));
        callbackBundle.push(_morphoCopyDebt(sourceParams, destParams, type(uint256).max, user, address(bundler)));
        callbackBundle.push(_morphoRepay(sourceParams, 0, borrowShares, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoWithdrawCollateral(sourceParams, collateralToSwap, address(bundler)));
        bundle.push(_morphoFlashLoan(sourceParams.collateralToken, collateralToSwap));
    }

    /* DEBT SWAP */

    function testPartialDebtSwap(uint256 borrowAmount, uint256 ratio) public {
        borrowAmount = bound(borrowAmount, MIN_AMOUNT, MAX_AMOUNT);
        uint256 collateralAmount = borrowAmount * 2;

        _supply(marketParams, borrowAmount, SUPPLIER);
        _supply(marketParamsLoan2, borrowAmount * 2, SUPPLIER);
        _supplyCollateral(marketParams, collateralAmount, USER);
        _borrow(marketParams, borrowAmount, address(USER));
        loanToken.setBalance(USER, 0);

        ratio = bound(ratio, MIN_RATIO, MAX_RATIO);
        uint256 debtToRepay = borrowAmount * ratio / WAD;
        uint256 collateralToTransfer = collateralAmount * ratio / WAD;
        _createPartialDebtSwapBundle(USER, marketParams, marketParamsLoan2, debtToRepay, collateralToTransfer);

        skip(2 days);

        uint256 expectedDebt = morpho.expectedBorrowAssets(marketParams, USER);

        vm.prank(USER);
        bundler.multicall(bundle);

        assertEq(morpho.collateral(marketParams.id(), USER), collateralAmount - collateralToTransfer, "collateral 1");
        assertEq(morpho.collateral(marketParamsLoan2.id(), USER), collateralToTransfer, "collateral 2");
        assertEq(morpho.expectedBorrowAssets(marketParams, USER), expectedDebt - debtToRepay, "loan 1");
        assertEq(morpho.expectedBorrowAssets(marketParamsLoan2, USER), debtToRepay, "loan 2"); // price is 1
    }

    // Method: supply collateral, borrow too much, buy exact, repay debt, repay leftover borrow, withdraw collateral
    // Issue: wasteful, must borrow too much
    function _createPartialDebtSwapBundle(
        address user,
        MarketParams memory sourceParams,
        MarketParams memory destParams,
        uint256 toRepay,
        uint256 collateralToTransfer
    ) internal {
        // overborrow to account for slippage
        // must keep 1 in balance so that second repay never fails
        uint256 toSell = toRepay * 101 / 100;
        uint256 toBorrow = toRepay * 101 / 100 + 1;

        callbackBundle.push(_morphoBorrow(destParams, toBorrow, 0, type(uint256).max, address(paraswapModule)));
        callbackBundle.push(
            _buy(destParams.loanToken, sourceParams.loanToken, toSell, toRepay, emptyMarketParams, address(bundler))
        );
        callbackBundle.push(_morphoRepay(sourceParams, type(uint256).max, 0, 0, user, hex""));
        callbackBundle.push(_morphoRepay(destParams, type(uint256).max, 0, 0, user, hex""));
        callbackBundle.push(_morphoWithdrawCollateral(sourceParams, collateralToTransfer, address(bundler)));
        bundle.push(_morphoSupplyCollateral(destParams, collateralToTransfer, user));
    }

    function testFullDebtSwap(uint256 borrowAmount) public {
        borrowAmount = bound(borrowAmount, MIN_AMOUNT, MAX_AMOUNT);
        uint256 collateralAmount = borrowAmount * 2;

        _supply(marketParams, borrowAmount, SUPPLIER);
        _supply(marketParamsLoan2, borrowAmount * 2, SUPPLIER);
        _supplyCollateral(marketParams, collateralAmount, USER);
        _borrow(marketParams, borrowAmount, address(USER));
        loanToken.setBalance(USER, 0);

        _createFullDebtSwapBundle(USER, marketParams, marketParamsLoan2);

        skip(2 days);

        uint256 expectedDebt = morpho.expectedBorrowAssets(marketParams, USER);

        vm.prank(USER);
        bundler.multicall(bundle);

        assertEq(morpho.collateral(marketParams.id(), USER), 0, "collateral 1");
        assertEq(morpho.collateral(marketParamsLoan2.id(), USER), collateralAmount, "collateral 2");
        assertEq(morpho.expectedBorrowAssets(marketParams, USER), 0, "loan 1");
        assertEq(morpho.expectedBorrowAssets(marketParamsLoan2, USER), expectedDebt, "loan 2");
    }

    // Method: supply collateral, borrow too much, buy exact, repay debt, repay leftover borrow, withdraw collateral
    function _createFullDebtSwapBundle(address user, MarketParams memory sourceParams, MarketParams memory destParams)
        internal
    {
        uint256 collateral = morpho.collateral(sourceParams.id(), user);
        uint256 borrowShares = morpho.borrowShares(sourceParams.id(), user);
        // will be adjusted
        uint256 toRepay = morpho.expectedBorrowAssets(sourceParams, user);
        // overborrow to account for slippage
        uint256 toBorrow = toRepay * 101 / 100;

        callbackBundle.push(_morphoBorrow(destParams, toBorrow, 0, type(uint256).max, address(paraswapModule)));
        // Buy amount will be adjusted inside the paraswap module to the current debt on sourceParams
        callbackBundle.push(
            _buy(destParams.loanToken, sourceParams.loanToken, toBorrow, toRepay, sourceParams, address(bundler))
        );
        callbackBundle.push(_morphoRepay(sourceParams, 0, borrowShares, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoRepay(destParams, type(uint256).max, 0, 0, user, hex""));
        callbackBundle.push(_morphoWithdrawCollateral(sourceParams, collateral, address(bundler)));
        bundle.push(_morphoSupplyCollateral(destParams, collateral, user));
    }

    /* REPAY WITH COLLATERAL */

    function testPartialRepayWithCollateral(uint256 borrowAmount, uint256 ratio) public {
        borrowAmount = bound(borrowAmount, MIN_AMOUNT, MAX_AMOUNT);
        uint256 collateralAmount = borrowAmount * 2;

        _supplyCollateral(marketParams, collateralAmount, SUPPLIER); // Need extra collateral for flashloan
        _supply(marketParams, borrowAmount, SUPPLIER);
        _supplyCollateral(marketParams, collateralAmount, USER);
        _borrow(marketParams, borrowAmount, address(USER));

        loanToken.setBalance(USER, 0);

        ratio = bound(ratio, MIN_RATIO, MAX_RATIO);
        uint256 assetsToRepay = borrowAmount * ratio / WAD;
        _createPartialRepayWithCollateralBundle(USER, marketParams, assetsToRepay);

        skip(2 days);

        uint256 expectedDebt = morpho.expectedBorrowAssets(marketParams, USER);

        vm.prank(USER);
        bundler.multicall(bundle);

        assertEq(morpho.collateral(marketParams.id(), USER), collateralAmount - assetsToRepay, "collateral");
        assertEq(morpho.expectedBorrowAssets(marketParams, USER), expectedDebt - assetsToRepay, "loan");
    }

    // Method: flashloan all current collateral, buy exact debt, repay debt, supply remaining collateral balance,
    // withdraw initial collateral
    // Limitation: fails if Morpho does not hold 2 * all collateral
    function _createPartialRepayWithCollateralBundle(
        address user,
        MarketParams memory marketParams,
        uint256 assetsToRepay
    ) internal {
        uint256 collateral = morpho.collateral(marketParams.id(), user);

        callbackBundle.push(_erc20Transfer(marketParams.collateralToken, address(paraswapModule), collateral));
        callbackBundle.push(
            _buy(
                marketParams.collateralToken,
                marketParams.loanToken,
                collateral,
                assetsToRepay,
                emptyMarketParams,
                address(bundler)
            )
        );
        callbackBundle.push(_morphoRepay(marketParams, assetsToRepay, 0, 0, user, hex""));
        // Cannot compute collateral - (remaining collateral), which would be the net amount to withdraw.
        // So do it in 2 steps: supply remaining collateral, then withdraw flashloaned amount.
        callbackBundle.push(_morphoSupplyCollateral(marketParams, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoWithdrawCollateral(marketParams, collateral, address(bundler)));
        bundle.push(_morphoFlashLoan(marketParams.collateralToken, collateral));
    }

    function testFullRepayWithCollateral(uint256 borrowAmount) public {
        borrowAmount = bound(borrowAmount, MIN_AMOUNT, MAX_AMOUNT);
        uint256 collateralAmount = borrowAmount * 2;

        _supplyCollateral(marketParams, collateralAmount, SUPPLIER); // Need extra collateral for flashloan
        _supply(marketParams, borrowAmount, SUPPLIER);
        _supplyCollateral(marketParams, collateralAmount, USER);
        _borrow(marketParams, borrowAmount, address(USER));

        loanToken.setBalance(USER, 0);

        _createFullRepayWithCollateralBundle(USER, marketParams);

        skip(2 days);

        uint256 expectedDebt = morpho.expectedBorrowAssets(marketParams, USER);

        vm.prank(USER);
        bundler.multicall(bundle);

        assertEq(morpho.collateral(marketParams.id(), USER), collateralAmount - expectedDebt, "collateral");
        assertEq(morpho.expectedBorrowAssets(marketParams, USER), 0, "loan");
    }

    // Method: flashloan all current collateral, buy exact debt, repay debt, supply remaining collateral balance,
    // withdraw initial collateral
    // Limitation: fails if Morpho does not hold 2 * all collateral
    function _createFullRepayWithCollateralBundle(address user, MarketParams memory marketParams) internal {
        uint256 collateral = morpho.collateral(marketParams.id(), user);
        uint256 assetsToBuy = collateral; // price is 1
        uint256 borrowShares = morpho.borrowShares(marketParams.id(), USER);

        callbackBundle.push(_erc20Transfer(marketParams.collateralToken, address(paraswapModule), collateral));
        // Buy amount will be adjusted inside the paraswap module to the current debt
        callbackBundle.push(
            _buy(
                marketParams.collateralToken,
                marketParams.loanToken,
                collateral,
                assetsToBuy,
                marketParams,
                address(bundler)
            )
        );
        callbackBundle.push(_morphoRepay(marketParams, 0, borrowShares, type(uint256).max, user, hex""));
        // Cannot compute collateral - (remaining collateral), which would be the net amount to withdraw.
        // So do it in 2 steps: supply remaining collateral, then withdraw flashloaned amount.
        callbackBundle.push(_morphoSupplyCollateral(marketParams, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoWithdrawCollateral(marketParams, collateral, address(bundler)));
        bundle.push(_morphoFlashLoan(marketParams.collateralToken, collateral));
    }
}
