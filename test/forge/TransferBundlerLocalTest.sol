// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";

import "./helpers/LocalTest.sol";

contract TransferBundlerLocalTest is LocalTest {
    function testTransfer(uint256 amount) public {
        amount = bound(amount, 0, MAX_AMOUNT);

        bundle.push(_erc20Transfer(address(loanToken), RECEIVER, amount));

        loanToken.setBalance(address(bundler), amount);

        hub.multicall(bundle);

        assertEq(loanToken.balanceOf(address(bundler)), 0, "loan.balanceOf(bundler)");
        assertEq(loanToken.balanceOf(RECEIVER), amount, "loan.balanceOf(RECEIVER)");
    }

    function testTranferZeroAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20Transfer(address(loanToken), address(0), amount));

        vm.expectRevert(bytes(ErrorsLib.ZERO_ADDRESS));
        hub.multicall(bundle);
    }

    function testTranferBundlerAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20Transfer(address(loanToken), address(bundler), amount));

        vm.expectRevert(bytes(ErrorsLib.BUNDLER_ADDRESS));
        hub.multicall(bundle);
    }

    function testNativeTransfer(uint256 amount) public {
        amount = bound(amount, 0, MAX_AMOUNT);

        bundle.push(_nativeTransfer(RECEIVER, amount));

        deal(address(hub), amount);

        hub.multicall(bundle);

        assertEq(address(bundler).balance, 0, "bundler.balance");
        assertEq(RECEIVER.balance, amount, "RECEIVER.balance");
    }

    function testNativeTransferZeroAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_nativeTransferNoFunding(address(0), amount));

        vm.expectRevert(bytes(ErrorsLib.ZERO_ADDRESS));
        hub.multicall(bundle);
    }

    function testNativeTransferBundlerAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_nativeTransferNoFunding(address(bundler), amount));

        vm.expectRevert(bytes(ErrorsLib.BUNDLER_ADDRESS));
        hub.multicall(bundle);
    }

    function testTransferFrom(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20TransferFrom(address(loanToken), amount));

        loanToken.setBalance(USER, amount);

        vm.startPrank(USER);
        loanToken.approve(address(bundler), type(uint256).max);
        hub.multicall(bundle);
        vm.stopPrank();

        assertEq(loanToken.balanceOf(address(bundler)), amount, "loan.balanceOf(bundler)");
        assertEq(loanToken.balanceOf(USER), 0, "loan.balanceOf(USER)");
    }

    function testTransferFromUnauthorized(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(bytes(ErrorsLib.UNAUTHORIZED_SENDER));
        bundler.erc20TransferFrom(address(loanToken), amount, RECEIVER);
    }

    function testTranferFromZeroAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20TransferFrom(address(0), amount));

        vm.prank(USER);
        vm.expectRevert();
        hub.multicall(bundle);
    }

    function testTranferFromZeroAmount() public {
        bundle.push(_erc20TransferFrom(address(loanToken), 0));

        vm.prank(USER);
        vm.expectRevert(bytes(ErrorsLib.ZERO_AMOUNT));
        hub.multicall(bundle);
    }
}
