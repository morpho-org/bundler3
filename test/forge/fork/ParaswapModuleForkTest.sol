// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IAllowanceTransfer} from "../../../lib/permit2/src/interfaces/IAllowanceTransfer.sol";

import {EthereumBundlerV2} from "../../../src/ethereum/EthereumBundlerV2.sol";
import {ChainAgnosticBundlerV2} from "../../../src/chain-agnostic/ChainAgnosticBundlerV2.sol";

import "./helpers/ForkTest.sol";

contract ParaswapModuleForkTest is ForkTest {
    function _forkBlockNumberKey() internal virtual override returns (string memory) {
        return "paraswap";
    }

    uint256 constant MAX_EXACT_VALUE_CHANGE_PERCENT = 140;

    // USDC -> DAI swap on Maker PSM through Augustus contract
    bytes sellCalldata =
        hex"987e7d8e000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000006b175474e89094c44da98b954eedeac495271d0f00000000000000000000000000000000000000000000000000000000004c4b4000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e8d4a51000000000000000000000000000f6e72db5454dd049d0788e411b06cfaf16853042000000000000000000000000f6e72db5454dd049d0788e411b06cfaf168530421fb0b8897eef47fc855b41a9149a21e2000000000000000000000000013e0708000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000000";
    uint256 srcAmount = 5000000;
    uint256 srcAmountOffset = 68;
    uint256 sellExpectedDestAmount = 5e18;

    function testSellNoAdjustment(uint256 privateKey, uint256 extra) public onlyEthereum {
        extra = bound(extra, 0, type(uint128).max);
        privateKey = boundPrivateKey(privateKey);
        address user = vm.addr(privateKey);

        deal(USDC, user, srcAmount + extra);

        bundle.push(_erc20TransferFromWithReceiver(USDC, address(paraswapModule), type(uint256).max));
        bundle.push(
            _moduleCall(
                address(paraswapModule),
                _paraswapSell(
                    AUGUSTUS_V6_2, sellCalldata, USDC, DAI, sellExpectedDestAmount, "", srcAmountOffset, address(user)
                )
            )
        );

        vm.startPrank(user);
        ERC20(USDC).approve(address(bundler), type(uint256).max);
        bundler.multicall(bundle);
        vm.stopPrank();

        assertEq(ERC20(USDC).balanceOf(address(user)), extra, "extra");
        assertEq(ERC20(DAI).balanceOf(address(user)), sellExpectedDestAmount, "bought");
    }

    function testSellWithAdjustment(uint256 privateKey, uint256 percent) public onlyEthereum {
        percent = bound(percent, 1, MAX_EXACT_VALUE_CHANGE_PERCENT);

        privateKey = boundPrivateKey(privateKey);
        address user = vm.addr(privateKey);

        deal(USDC, user, srcAmount * percent / 100);

        bundle.push(_erc20TransferFromWithReceiver(USDC, address(paraswapModule), type(uint256).max));
        bundle.push(_setVariableToBalanceOf("new sell amount", USDC, address(paraswapModule)));
        bundle.push(
            _moduleCall(
                address(paraswapModule),
                _paraswapSell(
                    AUGUSTUS_V6_2,
                    sellCalldata,
                    USDC,
                    DAI,
                    sellExpectedDestAmount,
                    "new sell amount",
                    srcAmountOffset,
                    address(user)
                )
            )
        );

        vm.startPrank(user);
        ERC20(USDC).approve(address(bundler), type(uint256).max);
        bundler.multicall(bundle);
        vm.stopPrank();

        assertEq(ERC20(USDC).balanceOf(address(user)), 0, "sold");
        assertEq(ERC20(DAI).balanceOf(address(user)), sellExpectedDestAmount * percent / 100, "bought");
    }

    // swapExactAmountOut
    bytes buyCalldata =
        hex"7f45767500000000000000000000000020004f017a0bc0050bc004d9c500a7a089800000000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000002260fac5e5542a773aa44fbcfedf7c193bc2c59900000000000000000000000000000000000000000000000000000010c9bceb290000000000000000000000000000000000000000000000000000000005f5e1000000000000000000000000000000000000000000000000000000000f4308d5c87a4da162a01c45aea07d3d85b5f761e1000000000000000000000000013e23eb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000360000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000003800000016000000000000000000000012000000000000001370000000000000640e592427a0aece92de3edee1f18e0157c058615640140008400a400000000000300000000000000000000000000000000000000000000000000000000f28c0498000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000006a000f20005980200259b80c510200304000106800000000000000000000000000000000000000000000000000000000670148f50000000000000000000000000000000000000000000000000000000000f4240000000000000000000000000000000000000000000000000000000002707f4c59000000000000000000000000000000000000000000000000000000000000002b2260fac5e5542a773aa44fbcfedf7c193bc2c5990001f4a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000000000000000000000000180000000000000000000000120000000000000014e00000000000020d0e592427a0aece92de3edee1f18e0157c058615640160008400a400000000000300000000000000000000000000000000000000000000000000000000f28c0498000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000006a000f20005980200259b80c510200304000106800000000000000000000000000000000000000000000000000000000670148f5000000000000000000000000000000000000000000000000000000000501bd000000000000000000000000000000000000000000000000000000000cd289896f00000000000000000000000000000000000000000000000000000000000000422260fac5e5542a773aa44fbcfedf7c193bc2c5990001f4c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20001f4a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000000000000000";
    uint256 destAmount = 1e8;
    uint256 destAmountOffset = 132;
    uint256 expectedSrcAmount = 65_549_161_928;

    function testBuyNoAdjustment(uint256 privateKey) public onlyEthereum {
        uint256 initialBalance = 1_000_000_000e6;
        privateKey = boundPrivateKey(privateKey);
        address user = vm.addr(privateKey);

        deal(USDC, user, initialBalance);

        bundle.push(_erc20TransferFromWithReceiver(USDC, address(paraswapModule), type(uint256).max));
        bundle.push(
            _moduleCall(
                address(paraswapModule),
                _paraswapBuy(
                    AUGUSTUS_V6_2, buyCalldata, USDC, WBTC, expectedSrcAmount, "", destAmountOffset, address(user)
                )
            )
        );

        vm.startPrank(user);
        ERC20(USDC).approve(address(bundler), type(uint256).max);
        bundler.multicall(bundle);
        vm.stopPrank();

        uint256 sold = initialBalance - ERC20(USDC).balanceOf(address(user));
        assertEq(sold, expectedSrcAmount, "sold");
        assertEq(ERC20(WBTC).balanceOf(address(user)), destAmount, "bought");
    }

    function testBuyWithAdjustment(uint256 privateKey, uint256 percent) public onlyEthereum {
        MarketParams memory wethWbtcMarketParams = MarketParams({
            collateralToken: WBTC,
            loanToken: WBTC,
            oracle: address(oracle),
            irm: address(irm),
            lltv: 0.8 ether
        });
        morpho.createMarket(wethWbtcMarketParams);
        // Cannot go above 100% because Augustus will often pull the maxSrcAmount encoded in the calldata upfront.
        // So adjusting up does not let the user actually sell more.
        // If adjusting below -90% the price will change too much.
        percent = bound(percent, 10, 100);
        uint256 debt = destAmount * percent / 100;
        uint256 initialBalance = 1_000_000_000e6;

        privateKey = boundPrivateKey(privateKey);
        address user = vm.addr(privateKey);

        deal(USDC, user, initialBalance);

        bundle.push(_erc20TransferFromWithReceiver(USDC, address(paraswapModule), type(uint256).max));

        bundle.push(_setVariable("new buy amount", debt));

        bundle.push(
            _moduleCall(
                address(paraswapModule),
                _paraswapBuy(
                    AUGUSTUS_V6_2,
                    buyCalldata,
                    USDC,
                    WBTC,
                    expectedSrcAmount * 110 / 100,
                    "new buy amount",
                    destAmountOffset,
                    address(user)
                )
            )
        );

        vm.startPrank(user);
        ERC20(USDC).approve(address(bundler), type(uint256).max);
        bundler.multicall(bundle);
        vm.stopPrank();

        uint256 sold = initialBalance - ERC20(USDC).balanceOf(address(user));
        assertApproxEqRel(sold, expectedSrcAmount * percent / 100, 10 * WAD / 100, "sold");
        assertEq(ERC20(WBTC).balanceOf(address(user)), debt, "bought");
    }
}
