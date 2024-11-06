// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../src/libraries/ErrorsLib.sol" as ErrorsLib;

import "./helpers/LocalTest.sol";

contract BaseBundlerLocalTest is LocalTest {
    BaseBundler baseBundler;

    function setUp() public override {
        super.setUp();
        baseBundler = new BaseBundler(address(hub));
    }

    function testTransfer(uint256 amount) public {
        amount = bound(amount, 0, MAX_AMOUNT);

        bundle.push(_erc20Transfer(address(loanToken), RECEIVER, amount, baseBundler));

        loanToken.setBalance(address(baseBundler), amount);

        hub.multicall(bundle);

        assertEq(loanToken.balanceOf(address(baseBundler)), 0, "loan.balanceOf(baseBundler)");
        assertEq(loanToken.balanceOf(RECEIVER), amount, "loan.balanceOf(RECEIVER)");
    }

    function testTranferZeroAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20Transfer(address(loanToken), address(0), amount, baseBundler));

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        hub.multicall(bundle);
    }

    function testTranferBundlerAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20Transfer(address(loanToken), address(baseBundler), amount, baseBundler));

        vm.expectRevert(ErrorsLib.BundlerAddress.selector);
        hub.multicall(bundle);
    }

    function testNativeTransfer(uint256 amount) public {
        amount = bound(amount, 0, MAX_AMOUNT);

        bundle.push(_nativeTransfer(RECEIVER, amount, baseBundler));

        deal(address(hub), amount);

        hub.multicall(bundle);

        assertEq(address(baseBundler).balance, 0, "baseBundler.balance");
        assertEq(RECEIVER.balance, amount, "RECEIVER.balance");
    }

    function testNativeTransferZeroAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_nativeTransferNoFunding(address(0), amount, baseBundler));

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        hub.multicall(bundle);
    }

    function testNativeTransferBundlerAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_nativeTransferNoFunding(address(baseBundler), amount, baseBundler));

        vm.expectRevert(ErrorsLib.BundlerAddress.selector);
        hub.multicall(bundle);
    }
}
