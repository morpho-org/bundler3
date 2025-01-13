// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";

import "./helpers/LocalTest.sol";

contract ConcreteCoreAdapter is CoreAdapter {
    constructor(address bundler3) CoreAdapter(bundler3) {}
}

contract CoreAdapterLocalTest is LocalTest {
    CoreAdapter internal coreAdapter;

    function setUp() public override {
        super.setUp();
        coreAdapter = new ConcreteCoreAdapter(address(bundler3));
    }

    function testTransfer(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20Transfer(address(loanToken), RECEIVER, amount, coreAdapter));

        deal(address(loanToken), address(coreAdapter), amount);

        bundler3.multicall(bundle);

        assertEq(loanToken.balanceOf(address(coreAdapter)), 0, "loan.balanceOf(coreAdapter)");
        assertEq(loanToken.balanceOf(RECEIVER), amount, "loan.balanceOf(RECEIVER)");
    }

    function testTransferZeroAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20Transfer(address(loanToken), address(0), amount, coreAdapter));

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        bundler3.multicall(bundle);
    }

    function testTransferAdapterAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20Transfer(address(loanToken), address(coreAdapter), amount, coreAdapter));

        vm.expectRevert(ErrorsLib.AdapterAddress.selector);
        bundler3.multicall(bundle);
    }

    function testTransferZeroExactAmount() public {
        bundle.push(_erc20Transfer(address(loanToken), RECEIVER, 0, coreAdapter));

        vm.prank(USER);
        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        bundler3.multicall(bundle);
    }

    function testTransferZeroBalanceAmount() public {
        bundle.push(_erc20Transfer(address(loanToken), RECEIVER, type(uint256).max, coreAdapter));

        vm.prank(USER);
        bundler3.multicall(bundle);
    }

    function testNativeTransfer(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_transferNativeToAdapter(payable(coreAdapter), amount));
        bundle.push(_nativeTransfer(RECEIVER, amount, coreAdapter));

        deal(address(bundler3), amount);

        bundler3.multicall(bundle);

        assertEq(address(coreAdapter).balance, 0, "coreAdapter.balance");
        assertEq(RECEIVER.balance, amount, "RECEIVER.balance");
    }

    function testNativeTransferZeroAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_nativeTransferNoFunding(address(0), amount, coreAdapter));

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        bundler3.multicall(bundle);
    }

    function testNativeTransferAdapterAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_nativeTransferNoFunding(address(coreAdapter), amount, coreAdapter));

        vm.expectRevert(ErrorsLib.AdapterAddress.selector);
        bundler3.multicall(bundle);
    }

    function testNativeTransferZeroExactAmount() public {
        bundle.push(_nativeTransferNoFunding(RECEIVER, 0, coreAdapter));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        bundler3.multicall(bundle);
    }

    function testNativeTransferZeroBalanceAmount() public {
        bundle.push(_nativeTransferNoFunding(RECEIVER, type(uint256).max, coreAdapter));

        bundler3.multicall(bundle);
    }
}
