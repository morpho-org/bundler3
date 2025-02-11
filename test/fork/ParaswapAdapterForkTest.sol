// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IAllowanceTransfer} from "../../lib/permit2/src/interfaces/IAllowanceTransfer.sol";
import {MockERC20} from "../../lib/permit2/test/mocks/MockERC20.sol";
import {ERC20Wrapper} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Wrapper.sol";

import "./helpers/ForkTest.sol";

contract ParaswapAdapterForkTest is ForkTest {
    address internal AUGUSTUS_V6_2 = getAddress("AUGUSTUS_V6_2");
    address internal USDC = getAddress("USDC");
    address internal WETH = getAddress("WETH");

    function setUp() public override {
        // block.chainid is only available after super.setUp
        if (config.chainid != 1) return;

        config.blockNumber = 20842056;
        // Morpho token does not exist at this block and test setup needs it.
        setAddress("MORPHO_TOKEN", address(new MockERC20("Mock Morpho Token", "MMT", 18)));
        // Morpho token wrapper does not exist at this block and EthereumGeneralAdapter needs it.
        vm.mockCall(
            getAddress("MORPHO_WRAPPER"),
            abi.encodeCall(ERC20Wrapper.underlying, ()),
            abi.encode(getAddress("MORPHO_TOKEN_LEGACY"))
        );
        super.setUp();
    }

    uint256 constant MAX_EXACT_VALUE_CHANGE_PERCENT = 140;

    // swapExactAmountIn
    bytes sellCalldata =
        hex"e3ead59e000000000000000000000000a600910b670804230e00a100000d28000ae005c0000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000000000b2d05e000000000000000000000000000000000000000000000000000e4a857a73d6dc00000000000000000000000000000000000000000000000000112639c6249b6e3d5fabb4621d594a018cb7ff4a18feace4000000000000000000000000013ed31f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000180000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000001a0e592427a0aece92de3edee1f18e0157c0586156400000140008400000000000300000000000000000000000000000000000000000000000000000000c04b8d59000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000006a000f20005980200259b80c510200304000106800000000000000000000000000000000000000000000000000000000670987b900000000000000000000000000000000000000000000000000000000b2d05e000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002ba0b86991c6218b36c1d19d4a2e9eb0ce3606eb480001f4c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000000000000000000000";
    uint256 srcAmount = 3_000e6;
    uint256 srcAmountOffset = 100;
    uint256 minDestAmountOffset = 132;
    uint256 quotedDestAmountOffset = 164;
    uint256 expectedDestAmount = 1.125 ether + 628_032_142_705_042 wei;

    function testSellNoAdjustment() public onlyEthereum {
        address user = makeAddr("Test User");

        deal(USDC, user, srcAmount);

        bundle.push(_erc20TransferFrom(USDC, address(paraswapAdapter), type(uint256).max));
        bundle.push(
            _call(
                paraswapAdapter,
                _paraswapSell(
                    AUGUSTUS_V6_2,
                    sellCalldata,
                    USDC,
                    WETH,
                    false,
                    Offsets(srcAmountOffset, minDestAmountOffset, 0),
                    user
                )
            )
        );

        vm.startPrank(user);
        IERC20(USDC).approve(address(generalAdapter1), type(uint256).max);
        bundler3.multicall(bundle);
        vm.stopPrank();

        assertEq(IERC20(USDC).balanceOf(user), 0, "remaining");
        assertEq(IERC20(WETH).balanceOf(user), expectedDestAmount, "bought");
    }

    function testSellWithAdjustment(uint256 percent) public onlyEthereum {
        percent = bound(percent, 1, MAX_EXACT_VALUE_CHANGE_PERCENT);
        address user = makeAddr("Test User");

        deal(USDC, user, srcAmount * percent / 100);

        bundle.push(_erc20TransferFrom(USDC, address(paraswapAdapter), type(uint256).max));
        bundle.push(
            _call(
                paraswapAdapter,
                _paraswapSell(
                    AUGUSTUS_V6_2,
                    sellCalldata,
                    USDC,
                    WETH,
                    true,
                    Offsets(srcAmountOffset, minDestAmountOffset, quotedDestAmountOffset),
                    user
                )
            )
        );

        vm.startPrank(user);
        IERC20(USDC).approve(address(generalAdapter1), type(uint256).max);
        bundler3.multicall(bundle);
        vm.stopPrank();

        assertEq(IERC20(USDC).balanceOf(user), 0, "sold");
        assertApproxEqRel(IERC20(WETH).balanceOf(user), expectedDestAmount * percent / 100, 2 * WAD / 100, "bought");
    }

    // swapExactAmountOut
    bytes buyCalldata =
        hex"7f45767500000000000000000000000020004f017a0bc0050bc004d9c500a7a089800000000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000000000ada46ad40000000000000000000000000000000000000000000000000de0b6b3a76400000000000000000000000000000000000000000000000000000000000090b3ae5be4d22ddcf355437ea22a71bbc942b09c000000000000000000000000013ed31f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000180000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001c0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000001e00000016000000000000000000000012000000000000001370000000000002710e592427a0aece92de3edee1f18e0157c058615640140008400a400000000000300000000000000000000000000000000000000000000000000000000f28c0498000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000006a000f20005980200259b80c510200304000106800000000000000000000000000000000000000000000000000000000670987ba0000000000000000000000000000000000000000000000000de0b6b3a76400000000000000000000000000000000000000000000000000000000000090b3ae5b000000000000000000000000000000000000000000000000000000000000002bc02aaa39b223fe8d0a0e5c4f27ead9083c756cc20001f4a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000";
    uint256 destAmount = 1 ether;
    uint256 destAmountOffset = 132;
    uint256 maxSrcAmountOffset = 100;
    uint256 quotedSrcAmountOffset = 164;
    uint256 expectedSrcAmount = 2665176719;

    function testBuyNoAdjustment() public onlyEthereum {
        uint256 initialBalance = 1_000_000_000e6;
        address user = makeAddr("Test User");

        deal(USDC, user, initialBalance);

        bundle.push(_erc20TransferFrom(USDC, address(paraswapAdapter), type(uint256).max));
        bundle.push(
            _call(
                paraswapAdapter,
                _paraswapBuy(
                    AUGUSTUS_V6_2, buyCalldata, USDC, WETH, 0, Offsets(destAmountOffset, maxSrcAmountOffset, 0), user
                )
            )
        );
        bundle.push(_erc20Transfer(address(USDC), user, type(uint256).max, paraswapAdapter));

        vm.startPrank(user);
        IERC20(USDC).approve(address(generalAdapter1), type(uint256).max);
        bundler3.multicall(bundle);
        vm.stopPrank();

        uint256 sold = initialBalance - IERC20(USDC).balanceOf(user);
        assertEq(sold, expectedSrcAmount, "sold");
        assertEq(IERC20(WETH).balanceOf(user), destAmount, "bought");
    }

    function testBuyWithAdjustment(uint256 percent) public onlyEthereum {
        MarketParams memory wethMarketParams = MarketParams({
            collateralToken: WETH,
            loanToken: WETH,
            oracle: address(oracle),
            irm: address(irm),
            lltv: 0.8 ether
        });
        morpho.createMarket(wethMarketParams);
        percent = bound(percent, 10, MAX_EXACT_VALUE_CHANGE_PERCENT);
        uint256 newDestAmount = destAmount * percent / 100;
        uint256 initialBalance = 1_000_000_000e6;

        address user = makeAddr("Test User");

        deal(USDC, user, initialBalance);
        deal(WETH, address(this), type(uint128).max, false);

        bundle.push(_erc20TransferFrom(USDC, address(paraswapAdapter), type(uint256).max));
        bundle.push(
            _call(
                paraswapAdapter,
                _paraswapBuy(
                    AUGUSTUS_V6_2,
                    buyCalldata,
                    USDC,
                    WETH,
                    newDestAmount,
                    Offsets(destAmountOffset, maxSrcAmountOffset, quotedSrcAmountOffset),
                    user
                )
            )
        );
        bundle.push(_erc20Transfer(address(USDC), user, type(uint256).max, paraswapAdapter));

        vm.startPrank(user);
        IERC20(USDC).approve(address(generalAdapter1), type(uint256).max);
        bundler3.multicall(bundle);
        vm.stopPrank();

        uint256 sold = initialBalance - IERC20(USDC).balanceOf(user);
        assertApproxEqRel(sold, expectedSrcAmount * percent / 100, 2 * WAD / 100, "sold");
        assertEq(IERC20(WETH).balanceOf(user), newDestAmount, "bought");
    }
}
