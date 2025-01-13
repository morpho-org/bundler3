// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";

import "./helpers/ForkTest.sol";

contract WNativeAdapterForkTest is ForkTest {
    address internal immutable WETH = getAddress("WETH");

    function setUp() public override {
        super.setUp();

        vm.prank(USER);
        IERC20(WETH).approve(address(generalAdapter1), type(uint256).max);
    }

    function testWrapZeroAmount(address receiver) public {
        bundle.push(_wrapNative(0, receiver));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        vm.prank(USER);
        bundler3.multicall(bundle);
    }

    function testWrapNative(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_transferNativeToAdapter(payable(generalAdapter1), amount));
        bundle.push(_wrapNative(amount, RECEIVER));

        deal(USER, amount);

        vm.prank(USER);
        bundler3.multicall{value: amount}(bundle);

        assertEq(IERC20(WETH).balanceOf(address(generalAdapter1)), 0, "Adapter's wrapped token balance");
        assertEq(IERC20(WETH).balanceOf(USER), 0, "User's wrapped token balance");
        assertEq(IERC20(WETH).balanceOf(RECEIVER), amount, "Receiver's wrapped token balance");

        assertEq(address(generalAdapter1).balance, 0, "Adapter's native token balance");
        assertEq(USER.balance, 0, "User's native token balance");
        assertEq(RECEIVER.balance, 0, "Receiver's native token balance");
    }

    function testUnwrapZeroAmount(address receiver) public {
        bundle.push(_unwrapNative(0, receiver));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        vm.prank(USER);
        bundler3.multicall(bundle);
    }

    function testUnwrapNative(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20TransferFrom(WETH, amount));
        bundle.push(_unwrapNative(amount, RECEIVER));

        deal(WETH, USER, amount);

        vm.prank(USER);
        bundler3.multicall(bundle);

        assertEq(IERC20(WETH).balanceOf(address(generalAdapter1)), 0, "Adapter's wrapped token balance");
        assertEq(IERC20(WETH).balanceOf(USER), 0, "User's wrapped token balance");
        assertEq(IERC20(WETH).balanceOf(RECEIVER), 0, "Receiver's wrapped token balance");

        assertEq(address(generalAdapter1).balance, 0, "Adapter's native token balance");
        assertEq(USER.balance, 0, "User's native token balance");
        assertEq(RECEIVER.balance, amount, "Receiver's native token balance");
    }
}
