// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";

import "./helpers/LocalTest.sol";
import {IAugustusRegistry} from "../src/interfaces/IAugustusRegistry.sol";
import {MathLib} from "../lib/morpho-blue/src/libraries/MathLib.sol";
import {EventsLib} from "../src/libraries/EventsLib.sol";
import {AugustusMock} from "../src/mocks/AugustusMock.sol";

contract ParaswapBundlerLocalTest is LocalTest {
    using MarketParamsLib for MarketParams;
    using MorphoBalancesLib for IMorpho;
    using MorphoLib for IMorpho;
    using MathLib for uint256;

    AugustusMock augustus;

    ERC20Mock collateralToken2;
    MarketParams internal marketParamsCollateral2;
    Id internal idCollateral2;

    ERC20Mock loanToken2;
    MarketParams internal marketParamsLoan2;
    Id internal idLoan2;

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
        augustus = new AugustusMock();
        augustusRegistryMock.setValid(address(augustus), true);

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
        morpho.setAuthorization(address(genericBundler1), true);
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
        uint256 srcAmount,
        uint256 minDestAmount,
        bool sellEntireBalance,
        address receiver
    ) internal view returns (Call memory) {
        return _call(
            paraswapBundler,
            _paraswapSell(
                address(augustus),
                abi.encodeCall(augustus.mockSell, (srcToken, destToken, srcAmount, minDestAmount)),
                srcToken,
                destToken,
                sellEntireBalance,
                Offsets(4 + 32 + 32, 4 + 32 + 32 + 32, 0),
                receiver
            )
        );
    }

    function _buy(
        address srcToken,
        address destToken,
        uint256 maxSrcAmount,
        uint256 destAmount,
        MarketParams memory marketParams,
        address receiver
    ) internal view returns (Call memory) {
        return _call(
            paraswapBundler,
            _paraswapBuy(
                address(augustus),
                abi.encodeCall(augustus.mockBuy, (srcToken, destToken, maxSrcAmount, destAmount)),
                srcToken,
                destToken,
                marketParams,
                Offsets(4 + 32 + 32 + 32, 4 + 32 + 32, 0),
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
        vm.assume(account != address(paraswapBundler));
        vm.assume(account != address(augustus));
        vm.assume(account != address(this));
    }

    function testAugustusInRegistrySellCheck(address _augustus) public {
        augustusRegistryMock.setValid(_augustus, false);

        vm.prank(address(hub));

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.AugustusNotInRegistry.selector, _augustus));
        paraswapBundler.sell(_augustus, hex"", address(0), address(0), true, Offsets(0, 0, 0), address(0));
    }

    function testAugustusInRegistryBuyCheck(address _augustus) public {
        augustusRegistryMock.setValid(_augustus, false);

        vm.prank(address(hub));

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.AugustusNotInRegistry.selector, _augustus));
        paraswapBundler.buy(_augustus, hex"", address(0), address(0), emptyMarketParams(), Offsets(0, 0, 0), address(0));
    }

    uint256 _bytesLength = 1024;

    function _boundOffset(uint256 offset) internal view returns (uint256) {
        return bound(offset, 0, _bytesLength - 32 * 3);
    }

    function _swapCalldata(uint256 offset, uint256 exactAmount, uint256 limitAmount, uint256 quotedAmount)
        internal
        view
        returns (bytes memory)
    {
        return bytes.concat(
            new bytes(offset),
            bytes32(exactAmount),
            bytes32(limitAmount),
            bytes32(quotedAmount),
            new bytes(_bytesLength - 32 * 3 - offset)
        );
    }

    function _updateAmountsSell(
        address _augustus,
        uint256 initialExact,
        uint256 initialLimit,
        uint256 initialQuoted,
        uint256 adjustedExact,
        uint256 offset,
        bool adjustQuoted
    ) internal {
        _callable(_augustus);
        augustusRegistryMock.setValid(_augustus, true);

        offset = _boundOffset(offset);

        initialExact = bound(initialExact, 1, type(uint64).max);
        initialLimit = bound(initialLimit, 0, type(uint64).max);
        initialQuoted = bound(initialQuoted, 0, type(uint64).max);
        adjustedExact = bound(adjustedExact, 0, type(uint64).max);
        uint256 adjustedLimit = initialLimit.mulDivUp(adjustedExact, initialExact);

        uint256 adjustedQuoted;
        uint256 quotedOffset;

        if (adjustQuoted) {
            adjustedQuoted = initialQuoted.mulDivUp(adjustedExact, initialExact);
            quotedOffset = offset + 64;
        } else {
            adjustedQuoted = initialQuoted;
            quotedOffset = 0;
        }

        collateralToken.setBalance(address(paraswapBundler), adjustedExact);

        if (adjustedLimit > 0) {
            vm.expectPartialRevert(ErrorsLib.BuyAmountTooLow.selector);
        }
        vm.expectCall(address(_augustus), _swapCalldata(offset, adjustedExact, adjustedLimit, adjustedQuoted));
        // adjustedData);
        bundle.push(
            _call(
                paraswapBundler,
                _paraswapSell(
                    _augustus,
                    _swapCalldata(offset, initialExact, initialLimit, initialQuoted),
                    address(collateralToken),
                    address(loanToken),
                    true,
                    Offsets(offset, offset + 32, quotedOffset),
                    address(1)
                )
            )
        );
        hub.multicall(bundle);
    }

    function testUpdateAmountsSellWithQuoteUpdate(
        address _augustus,
        uint256 initialExact,
        uint256 initialLimit,
        uint256 initialQuoted,
        uint256 adjustedExact,
        uint256 offset
    ) public {
        _updateAmountsSell(_augustus, initialExact, initialLimit, initialQuoted, adjustedExact, offset, true);
    }

    function testUpdateAmountsSellNoQuoteUpdate(
        address _augustus,
        uint256 initialExact,
        uint256 initialLimit,
        uint256 initialQuoted,
        uint256 adjustedExact,
        uint256 offset
    ) public {
        _updateAmountsSell(_augustus, initialExact, initialLimit, initialQuoted, adjustedExact, offset, false);
    }

    function _updateAmountsBuy(
        address _augustus,
        uint256 initialExact,
        uint256 initialLimit,
        uint256 initialQuoted,
        uint256 adjustedExact,
        uint256 offset,
        bool adjustQuoted
    ) internal {
        _callable(_augustus);
        augustusRegistryMock.setValid(_augustus, true);

        offset = _boundOffset(offset);

        initialExact = bound(initialExact, 1, type(uint64).max);
        initialLimit = bound(initialLimit, 0, type(uint64).max);
        initialQuoted = bound(initialQuoted, 0, type(uint64).max);
        adjustedExact = bound(adjustedExact, 1, type(uint64).max);

        uint256 adjustedLimit = initialLimit.mulDivDown(adjustedExact, initialExact);

        uint256 adjustedQuoted;
        uint256 quotedOffset;
        if (adjustQuoted) {
            adjustedQuoted = initialQuoted.mulDivDown(adjustedExact, initialExact);
            quotedOffset = offset + 64;
        } else {
            adjustedQuoted = initialQuoted;
            quotedOffset = 0;
        }

        _supplyCollateral(marketParams, type(uint104).max, address(this));
        _supply(marketParams, type(uint104).max, address(this));
        _borrow(marketParams, adjustedExact, address(this));

        vm.expectPartialRevert(ErrorsLib.BuyAmountTooLow.selector);
        vm.expectCall(address(_augustus), _swapCalldata(offset, adjustedExact, adjustedLimit, adjustedQuoted));
        bundle.push(
            _call(
                paraswapBundler,
                _paraswapBuy(
                    _augustus,
                    _swapCalldata(offset, initialExact, initialLimit, initialQuoted),
                    address(collateralToken),
                    address(loanToken),
                    marketParams,
                    Offsets(offset, offset + 32, quotedOffset),
                    address(1)
                )
            )
        );
        hub.multicall(bundle);
    }

    function testUpdateAmountsBuyWithQuoteUpdate(
        address _augustus,
        uint256 initialExact,
        uint256 initialLimit,
        uint256 initialQuoted,
        uint256 adjustedExact,
        uint256 offset
    ) public {
        _updateAmountsBuy(_augustus, initialExact, initialLimit, initialQuoted, adjustedExact, offset, true);
    }

    function testUpdateAmountsBuyNoQuoteUpdate(
        address _augustus,
        uint256 initialExact,
        uint256 initialLimit,
        uint256 initialQuoted,
        uint256 adjustedExact,
        uint256 offset
    ) public {
        _updateAmountsBuy(_augustus, initialExact, initialLimit, initialQuoted, adjustedExact, offset, false);
    }

    function testIncorrectLoanToken(address argToken, address marketToken) public {
        vm.assume(marketToken != address(0));
        vm.assume(argToken != marketToken);

        marketParams.loanToken = marketToken;

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.IncorrectLoanToken.selector, marketParams.loanToken));
        vm.prank(address(hub));
        paraswapBundler.buy(
            address(augustus),
            new bytes(32),
            address(collateralToken),
            argToken,
            marketParams,
            Offsets(0, 0, 0),
            address(0)
        );
    }

    function testBuyExactAmountCheck(uint256 amount, uint256 subAmount) public {
        amount = bound(amount, 1, type(uint64).max);
        subAmount = bound(subAmount, 0, amount - 1);

        collateralToken.setBalance(address(paraswapBundler), amount);

        augustus.setToGive(subAmount);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.BuyAmountTooLow.selector, subAmount));
        bundle.push(
            _buy(address(collateralToken), address(loanToken), amount, amount, emptyMarketParams(), address(this))
        );
        hub.multicall(bundle);
    }

    function testSellExactAmountCheck(uint256 amount, uint256 supAmount) public {
        amount = bound(amount, 1, type(uint64).max);
        supAmount = bound(supAmount, amount + 1, type(uint120).max);

        collateralToken.setBalance(address(paraswapBundler), supAmount);

        augustus.setToTake(supAmount);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.SellAmountTooHigh.selector, supAmount));
        bundle.push(_sell(address(collateralToken), address(loanToken), amount, amount, false, address(this)));
        hub.multicall(bundle);
    }

    function testSwapEventSell(bytes32 salt, uint256 srcAmount, uint256 destAmount, address receiver) public {
        _receiver(receiver);
        srcAmount = bound(srcAmount, 0, type(uint128).max);
        destAmount = bound(destAmount, 0, type(uint128).max);

        augustus.setToTake(srcAmount);
        augustus.setToGive(destAmount);

        ERC20Mock srcToken = new ERC20Mock{salt: salt}("src", "SRC");
        ERC20Mock destToken = new ERC20Mock{salt: salt}("dest", "DEST");

        srcToken.setBalance(address(paraswapBundler), srcAmount);

        vm.expectEmit(true, true, true, true, address(paraswapBundler));
        emit EventsLib.ParaswapBundlerSwap(address(srcToken), address(destToken), receiver, srcAmount, destAmount);

        bundle.push(_sell(address(srcToken), address(destToken), srcAmount, destAmount, false, receiver));
        hub.multicall(bundle);
    }

    function testSwapEventBuy(bytes32 salt, uint256 srcAmount, uint256 destAmount, address receiver) public {
        _receiver(receiver);
        srcAmount = bound(srcAmount, 0, type(uint128).max);
        destAmount = bound(destAmount, 0, type(uint128).max);

        augustus.setToTake(srcAmount);
        augustus.setToGive(destAmount);

        ERC20Mock srcToken = new ERC20Mock{salt: salt}("src", "SRC");
        ERC20Mock destToken = new ERC20Mock{salt: salt}("dest", "DEST");

        srcToken.setBalance(address(paraswapBundler), srcAmount);

        vm.expectEmit(true, true, true, true, address(paraswapBundler));
        emit EventsLib.ParaswapBundlerSwap(address(srcToken), address(destToken), receiver, srcAmount, destAmount);

        bundle.push(_buy(address(srcToken), address(destToken), srcAmount, destAmount, emptyMarketParams(), receiver));
        hub.multicall(bundle);
    }

    function testSellSlippageCheckNoAdjustment(uint256 srcAmount, uint256 adjust) public {
        srcAmount = bound(srcAmount, 1, type(uint128).max);
        adjust = bound(adjust, 1, type(uint128).max);
        uint256 minDestAmount = srcAmount + adjust;

        collateralToken.setBalance(address(paraswapBundler), srcAmount);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.BuyAmountTooLow.selector, srcAmount));
        bundle.push(_sell(address(collateralToken), address(loanToken), srcAmount, minDestAmount, false, address(this)));
        hub.multicall(bundle);
    }

    function testBuySlippageCheckNoAdjustment(uint256 destAmount, uint256 adjust) public {
        destAmount = bound(destAmount, 1, type(uint128).max);
        adjust = bound(adjust, 1, destAmount);
        uint256 maxSrcAmount = destAmount - adjust;

        collateralToken.setBalance(address(paraswapBundler), destAmount); // price is 1

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.SellAmountTooHigh.selector, destAmount));
        bundle.push(
            _buy(
                address(collateralToken),
                address(loanToken),
                maxSrcAmount,
                destAmount,
                emptyMarketParams(),
                address(this)
            )
        );
        hub.multicall(bundle);
    }

    function testSellSlippageCheckWithAdjustment(uint256 srcAmount, uint256 adjust, uint256 percent) public {
        percent = bound(percent, 1, 1000);
        srcAmount = bound(srcAmount, 1, type(uint120).max);
        adjust = bound(adjust, 1, srcAmount);
        uint256 minDestAmount = srcAmount + adjust;

        collateralToken.setBalance(address(paraswapBundler), srcAmount.mulDivUp(percent, 100));

        vm.expectPartialRevert(ErrorsLib.BuyAmountTooLow.selector);
        bundle.push(_sell(address(collateralToken), address(loanToken), srcAmount, minDestAmount, true, address(this)));
        hub.multicall(bundle);
    }

    function testBuySlippageCheckWithAdjustment(uint256 destAmount, uint256 adjust, uint256 percent) public {
        percent = bound(percent, 1, 1000);
        destAmount = bound(destAmount, 1, type(uint64).max);
        adjust = bound(adjust, 1, destAmount);
        uint256 maxSrcAmount = destAmount - adjust;
        uint256 debt = destAmount.mulDivUp(percent, 100);

        _supplyCollateral(marketParams, type(uint104).max, address(this));
        _supply(marketParams, type(uint104).max, address(this));
        _borrow(marketParams, debt, address(this));
        collateralToken.setBalance(address(paraswapBundler), type(uint128).max);

        vm.expectPartialRevert(ErrorsLib.SellAmountTooHigh.selector);
        bundle.push(
            _buy(address(collateralToken), address(loanToken), maxSrcAmount, destAmount, marketParams, address(this))
        );
        hub.multicall(bundle);
    }

    function testSellNoAdjustment(uint256 amount, uint256 extra, address receiver) public {
        _receiver(receiver);

        amount = bound(amount, 1, type(uint128).max);
        extra = bound(extra, 0, type(uint128).max);

        collateralToken.setBalance(address(paraswapBundler), amount + extra);
        bundle.push(_sell(address(collateralToken), address(loanToken), amount, amount, false, receiver));
        hub.multicall(bundle);
        assertEq(collateralToken.balanceOf(receiver), extra, "receiver collateral");
        assertEq(loanToken.balanceOf(receiver), amount, "receiver loan token");
        assertEq(collateralToken.balanceOf(address(paraswapBundler)), 0, "paraswap module collateral");
        assertEq(loanToken.balanceOf(address(paraswapBundler)), 0, "paraswap module loan token");
    }

    function testBuyNoAdjustment(uint256 amount, uint256 extra, address receiver) public {
        _receiver(receiver);

        amount = bound(amount, 1, type(uint128).max);
        extra = bound(extra, 0, type(uint128).max);

        collateralToken.setBalance(address(paraswapBundler), amount + extra);
        bundle.push(_buy(address(collateralToken), address(loanToken), amount, amount, emptyMarketParams(), receiver));
        hub.multicall(bundle);
        assertEq(collateralToken.balanceOf(receiver), extra, "receiver collateral");
        assertEq(loanToken.balanceOf(receiver), amount, "receiver loan token");
        assertEq(collateralToken.balanceOf(address(paraswapBundler)), 0, "paraswap module collateral");
        assertEq(loanToken.balanceOf(address(paraswapBundler)), 0, "paraswap module loan token");
    }

    function testSellWithAdjustment(uint256 srcAmount, uint256 percent, address receiver) public {
        _receiver(receiver);

        percent = bound(percent, 1, 1000);
        srcAmount = bound(srcAmount, 1, type(uint120).max);
        uint256 actualSrcAmount = srcAmount.mulDivUp(percent, 100);

        collateralToken.setBalance(address(paraswapBundler), actualSrcAmount);
        bundle.push(_sell(address(collateralToken), address(loanToken), srcAmount, srcAmount, true, receiver));
        hub.multicall(bundle);
        assertEq(collateralToken.balanceOf(receiver), 0, "receiver collateral");
        assertEq(loanToken.balanceOf(receiver), actualSrcAmount, "receiver loan token");
        assertEq(collateralToken.balanceOf(address(paraswapBundler)), 0, "paraswap module collateral");
        assertEq(loanToken.balanceOf(address(paraswapBundler)), 0, "paraswap module loan token");
    }

    function testBuyWithAdjustment(uint256 destAmount, uint256 percent, address receiver) public {
        _receiver(receiver);

        percent = bound(percent, 1, 1000);
        destAmount = bound(destAmount, 1, type(uint64).max);
        uint256 actualDestAmount = destAmount.mulDivUp(percent, 100);

        _supplyCollateral(marketParams, type(uint104).max, address(this));
        _supply(marketParams, type(uint104).max, address(this));
        _borrow(marketParams, actualDestAmount, address(this));
        collateralToken.setBalance(address(paraswapBundler), actualDestAmount);

        bundle.push(_buy(address(collateralToken), address(loanToken), destAmount, destAmount, marketParams, receiver));
        hub.multicall(bundle);
        assertEq(collateralToken.balanceOf(receiver), 0, "receiver collateral");
        assertEq(loanToken.balanceOf(receiver), actualDestAmount, "receiver loan token");
        assertEq(collateralToken.balanceOf(address(paraswapBundler)), 0, "paraswap module collateral");
        assertEq(loanToken.balanceOf(address(paraswapBundler)), 0, "paraswap module loan token");
    }

    function testApprovalResetSell(uint256 amount) public {
        collateralToken.setBalance(address(paraswapBundler), amount);
        bundle.push(_sell(address(collateralToken), address(loanToken), amount, amount, false, address(this)));
        hub.multicall(bundle);
        assertEq(collateralToken.allowance(address(paraswapBundler), address(augustus)), 0);
    }

    function testApprovalResetBuy(uint256 amount) public {
        collateralToken.setBalance(address(paraswapBundler), amount);
        bundle.push(
            _buy(address(collateralToken), address(loanToken), amount, amount, emptyMarketParams(), address(this))
        );
        hub.multicall(bundle);
        assertEq(collateralToken.allowance(address(paraswapBundler), address(augustus)), 0);
    }

    /* WITHDRAW COLLATERAL AND SWAP */

    function testWithdrawCollateralAndSwap(uint256 collateralAmount, uint256 ratio) public {
        collateralAmount = bound(collateralAmount, MIN_AMOUNT, MAX_AMOUNT);

        _supplyCollateral(marketParams, collateralAmount, USER);

        ratio = bound(ratio, MIN_RATIO, WAD);
        uint256 srcAmount = collateralAmount * ratio / WAD;
        _createWithdrawCollateralAndSwapBundle(marketParams, address(collateralToken2), srcAmount, USER);

        skip(2 days);

        vm.prank(USER);
        hub.multicall(bundle);

        assertEq(morpho.collateral(marketParams.id(), USER), collateralAmount - srcAmount, "sold");
        assertEq(collateralToken2.balanceOf(USER), srcAmount, "bought"); // price is 1
    }

    // Method: withdraw X or all, sell exact amount
    // Works for both partial & full
    function _createWithdrawCollateralAndSwapBundle(
        MarketParams memory marketParams,
        address destToken,
        uint256 srcAmount,
        address receiver
    ) internal {
        bundle.push(_morphoWithdrawCollateral(marketParams, srcAmount, address(paraswapBundler)));
        bundle.push(_sell(marketParams.collateralToken, destToken, srcAmount, srcAmount, false, receiver));
    }

    /* WITHDRAW AND SWAP */

    function testPartialWithdrawAndSwap(uint256 supplyAmount, uint256 ratio) public {
        supplyAmount = bound(supplyAmount, MIN_AMOUNT, MAX_AMOUNT);

        _supply(marketParams, supplyAmount, USER);

        ratio = bound(ratio, MIN_RATIO, MAX_RATIO);
        uint256 srcAmount = supplyAmount * ratio / WAD;
        _createPartialWithdrawAndSwapBundle(marketParams, address(loanToken2), srcAmount, USER);

        skip(2 days);

        vm.prank(USER);
        hub.multicall(bundle);

        assertEq(morpho.expectedSupplyAssets(marketParams, USER), supplyAmount - srcAmount, "sold");
        assertEq(loanToken2.balanceOf(USER), srcAmount, "bought"); // price is 1
    }

    // Method: withdraw X, sell exact amount
    function _createPartialWithdrawAndSwapBundle(
        MarketParams memory marketParams,
        address destToken,
        uint256 assetsToWithdraw,
        address receiver
    ) internal {
        bundle.push(_morphoWithdraw(marketParams, assetsToWithdraw, 0, type(uint256).max, address(paraswapBundler)));
        bundle.push(_sell(marketParams.loanToken, destToken, assetsToWithdraw, assetsToWithdraw, false, receiver));
    }

    function testFullWithdrawAndSwap(uint256 supplyAmount) public {
        supplyAmount = bound(supplyAmount, MIN_AMOUNT, MAX_AMOUNT);

        _supply(marketParams, supplyAmount, USER);

        _createFullWithdrawAndSwapBundle(USER, marketParams, address(loanToken2), USER);

        skip(2 days);

        vm.prank(USER);
        hub.multicall(bundle);

        assertEq(morpho.expectedSupplyAssets(marketParams, USER), 0, "sold");
        assertEq(loanToken2.balanceOf(USER), supplyAmount, "bought");
    }

    // Method: withdraw all, sell exact amount (replaced by current balance by paraswap bundler)
    function _createFullWithdrawAndSwapBundle(
        address user,
        MarketParams memory marketParams,
        address destToken,
        address receiver
    ) internal {
        uint256 sharesToWithdraw = morpho.supplyShares(marketParams.id(), user);
        uint256 currentAssets = morpho.expectedSupplyAssets(marketParams, user);
        bundle.push(_morphoWithdraw(marketParams, 0, sharesToWithdraw, 0, address(paraswapBundler)));
        // Sell amount will be adjusted inside the paraswap bundler to the current balance
        bundle.push(_sell(marketParams.loanToken, destToken, currentAssets, currentAssets, true, receiver));
    }

    /* SUPPLY SWAP */

    function testPartialSupplySwap(uint256 supplyAmount, uint256 ratio) public {
        supplyAmount = bound(supplyAmount, MIN_AMOUNT, MAX_AMOUNT);

        _supply(marketParams, supplyAmount, USER);

        ratio = bound(ratio, MIN_RATIO, MAX_RATIO);
        uint256 srcAmount = supplyAmount * ratio / WAD;
        _createPartialSupplySwapBundle(USER, marketParams, marketParamsLoan2, address(loanToken2), srcAmount);

        skip(2 days);

        vm.prank(USER);
        hub.multicall(bundle);

        assertEq(morpho.expectedSupplyAssets(marketParams, USER), supplyAmount - srcAmount, "withdrawn");
        assertEq(morpho.expectedSupplyAssets(marketParamsLoan2, USER), srcAmount, "supplied");
    }

    // Method: withdraw X, sell exact amount, supply all
    function _createPartialSupplySwapBundle(
        address user,
        MarketParams memory sourceParams,
        MarketParams memory destParams,
        address destToken,
        uint256 assetsToWithdraw
    ) internal {
        _createPartialWithdrawAndSwapBundle(sourceParams, destToken, assetsToWithdraw, address(genericBundler1));
        bundle.push(_morphoSupply(destParams, type(uint256).max, 0, 0, user, hex""));
    }

    function testFullSupplySwap(uint256 supplyAmount) public {
        supplyAmount = bound(supplyAmount, MIN_AMOUNT, MAX_AMOUNT);

        _supply(marketParams, supplyAmount, USER);

        _createFullSupplySwapBundle(USER, marketParams, marketParamsLoan2);

        skip(2 days);

        vm.prank(USER);
        hub.multicall(bundle);

        assertEq(morpho.expectedSupplyAssets(marketParams, USER), 0, "withdrawn");
        assertEq(morpho.expectedSupplyAssets(marketParamsLoan2, USER), supplyAmount, "supplied");
    }

    // Method: withdraw all, sell all, supply all
    function _createFullSupplySwapBundle(address user, MarketParams memory sourceParams, MarketParams memory destParams)
        internal
    {
        _createFullWithdrawAndSwapBundle(user, sourceParams, destParams.loanToken, address(genericBundler1));
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
        hub.multicall(bundle);

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
        callbackBundle.push(_morphoWithdrawCollateral(sourceParams, collateralToSwap, address(paraswapBundler)));
        callbackBundle.push(
            _sell(
                sourceParams.collateralToken,
                destParams.collateralToken,
                collateralToSwap,
                collateralToSwap,
                false,
                address(genericBundler1)
            )
        );
        callbackBundle.push(_morphoSupplyCollateral(destParams, type(uint256).max, user, hex""));
        callbackBundle.push(
            _morphoBorrow(destParams, borrowAssetsToTransfer, 0, type(uint256).max, address(genericBundler1))
        );
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
        hub.multicall(bundle);

        assertEq(morpho.collateral(marketParams.id(), USER), 0);
        assertEq(morpho.collateral(marketParamsCollateral2.id(), USER), collateralAmount);
        assertEq(morpho.expectedBorrowAssets(marketParams, USER), 0);
        assertEq(morpho.expectedBorrowAssets(marketParamsCollateral2, USER), expectedDebt);
    }

    // Method: flashloan, sell exact collateral, supply collateral, borrow more than necessary from destMarket, repay
    // all shares on sourceMarket, repay remainnig balance on destMarket, withdraw collateral
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
        uint256 borrowShares = morpho.borrowShares(sourceParams.id(), user);
        uint256 collateralToSwap = morpho.collateral(sourceParams.id(), user);
        uint256 overestimatedDebtToRepay = morpho.expectedBorrowAssets(sourceParams, user) * 101 / 100;

        callbackBundle.push(
            _erc20Transfer(sourceParams.collateralToken, address(paraswapBundler), collateralToSwap, genericBundler1)
        );
        callbackBundle.push(
            _sell(
                sourceParams.collateralToken,
                destParams.collateralToken,
                collateralToSwap,
                collateralToSwap,
                true,
                address(genericBundler1)
            )
        );
        callbackBundle.push(_morphoSupplyCollateral(destParams, type(uint256).max, user));
        callbackBundle.push(
            _morphoBorrow(destParams, overestimatedDebtToRepay, 0, type(uint256).max, address(genericBundler1))
        );
        callbackBundle.push(_morphoRepay(sourceParams, 0, borrowShares, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoRepay(destParams, type(uint256).max, 0, 0, user, hex""));
        callbackBundle.push(_morphoWithdrawCollateral(sourceParams, collateralToSwap, address(genericBundler1)));
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
        hub.multicall(bundle);

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

        callbackBundle.push(_morphoBorrow(destParams, toBorrow, 0, type(uint256).max, address(paraswapBundler)));
        callbackBundle.push(
            _buy(
                destParams.loanToken,
                sourceParams.loanToken,
                toSell,
                toRepay,
                emptyMarketParams(),
                address(genericBundler1)
            )
        );
        callbackBundle.push(_morphoRepay(sourceParams, type(uint256).max, 0, 0, user, hex""));
        callbackBundle.push(_morphoRepay(destParams, type(uint256).max, 0, 0, user, hex""));
        callbackBundle.push(_morphoWithdrawCollateral(sourceParams, collateralToTransfer, address(genericBundler1)));
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
        hub.multicall(bundle);

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

        callbackBundle.push(_morphoBorrow(destParams, toBorrow, 0, type(uint256).max, address(paraswapBundler)));
        // Buy amount will be adjusted inside the paraswap  to the current debt on sourceParams
        callbackBundle.push(
            _buy(
                destParams.loanToken, sourceParams.loanToken, toBorrow, toRepay, sourceParams, address(genericBundler1)
            )
        );
        callbackBundle.push(_morphoRepay(sourceParams, 0, borrowShares, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoRepay(destParams, type(uint256).max, 0, 0, user, hex""));
        callbackBundle.push(_morphoWithdrawCollateral(sourceParams, collateral, address(genericBundler1)));
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
        hub.multicall(bundle);

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

        callbackBundle.push(
            _erc20Transfer(marketParams.collateralToken, address(paraswapBundler), collateral, genericBundler1)
        );
        callbackBundle.push(
            _buy(
                marketParams.collateralToken,
                marketParams.loanToken,
                collateral,
                assetsToRepay,
                emptyMarketParams(),
                address(genericBundler1)
            )
        );
        callbackBundle.push(_morphoRepay(marketParams, assetsToRepay, 0, 0, user, hex""));
        // Cannot compute collateral - (remaining collateral), which would be the net amount to withdraw.
        // So do it in 2 steps: supply remaining collateral, then withdraw flashloaned amount.
        callbackBundle.push(_morphoSupplyCollateral(marketParams, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoWithdrawCollateral(marketParams, collateral, address(genericBundler1)));
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
        hub.multicall(bundle);

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

        callbackBundle.push(
            _erc20Transfer(marketParams.collateralToken, address(paraswapBundler), collateral, genericBundler1)
        );
        // Buy amount will be adjusted inside the paraswap bundler to the current debt
        callbackBundle.push(
            _buy(
                marketParams.collateralToken,
                marketParams.loanToken,
                collateral,
                assetsToBuy,
                marketParams,
                address(genericBundler1)
            )
        );
        callbackBundle.push(_morphoRepay(marketParams, 0, borrowShares, type(uint256).max, user, hex""));
        // Cannot compute collateral - (remaining collateral), which would be the net amount to withdraw.
        // So do it in 2 steps: supply remaining collateral, then withdraw flashloaned amount.
        callbackBundle.push(_morphoSupplyCollateral(marketParams, type(uint256).max, user, hex""));
        callbackBundle.push(_morphoWithdrawCollateral(marketParams, collateral, address(genericBundler1)));
        bundle.push(_morphoFlashLoan(marketParams.collateralToken, collateral));
    }
}
