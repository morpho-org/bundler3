// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";

import "./helpers/ForkTest.sol";

contract WNativeModuleForkTest is ForkTest {
    function setUp() public override {
        super.setUp();

        vm.prank(USER);
        ERC20(WETH).approve(address(genericModule1), type(uint256).max);
    }

    function testWrapZeroAmount(address receiver) public {
        bundle.push(_wrapNative(0, receiver));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        vm.prank(USER);
        bundler.multicall(bundle);
    }

    function testWrapNative(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_wrapNative(amount, RECEIVER));

        deal(USER, amount);

        vm.prank(USER);
        bundler.multicall{value: amount}(bundle);

        assertEq(ERC20(WETH).balanceOf(address(genericModule1)), 0, "Module's wrapped token balance");
        assertEq(ERC20(WETH).balanceOf(USER), 0, "User's wrapped token balance");
        assertEq(ERC20(WETH).balanceOf(RECEIVER), amount, "Receiver's wrapped token balance");

        assertEq(address(genericModule1).balance, 0, "Module's native token balance");
        assertEq(USER.balance, 0, "User's native token balance");
        assertEq(RECEIVER.balance, 0, "Receiver's native token balance");
    }

    function testUnwrapZeroAmount(address receiver) public {
        bundle.push(_unwrapNative(0, receiver));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        vm.prank(USER);
        bundler.multicall(bundle);
    }

    // function testX() public {
    //     testUnwrapNative(1003);
    // }
    function testUnwrapNative(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20TransferFrom(WETH, amount));
        bundle.push(_unwrapNative(amount, RECEIVER));

        deal(WETH, USER, amount);

        console.log("WETH", WETH);
        console.log(WETH.balance);
        address WN = address(genericModule1.WRAPPED_NATIVE());
        console.log("WNATIVE", WN);
        console.log(WN.balance);

        vm.prank(USER);
        bundler.multicall(bundle);

        assertEq(ERC20(WETH).balanceOf(address(genericModule1)), 0, "Module's wrapped token balance");
        assertEq(ERC20(WETH).balanceOf(USER), 0, "User's wrapped token balance");
        assertEq(ERC20(WETH).balanceOf(RECEIVER), 0, "Receiver's wrapped token balance");

        assertEq(address(genericModule1).balance, 0, "Module's native token balance");
        assertEq(USER.balance, 0, "User's native token balance");
        assertEq(RECEIVER.balance, amount, "Receiver's native token balance");
    }
}
