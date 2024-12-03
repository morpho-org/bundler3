// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";

import "./helpers/LocalTest.sol";

contract ConcreteCoreAdapter is CoreAdapter {
    constructor(address initMulticall) CoreAdapter(initMulticall) {}
}

contract CoreAdapterLocalTest is LocalTest {
    CoreAdapter internal coreAdapter;

    function setUp() public override {
        super.setUp();
        coreAdapter = new ConcreteCoreAdapter(address(initMulticall));
    }

    function testTransfer(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20Transfer(address(loanToken), RECEIVER, amount, coreAdapter));

        deal(address(loanToken), address(coreAdapter), amount);

        initMulticall.multicall(bundle);

        assertEq(loanToken.balanceOf(address(coreAdapter)), 0, "loan.balanceOf(coreAdapter)");
        assertEq(loanToken.balanceOf(RECEIVER), amount, "loan.balanceOf(RECEIVER)");
    }

    function testTransferZeroAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20Transfer(address(loanToken), address(0), amount, coreAdapter));

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        initMulticall.multicall(bundle);
    }

    function testTransferAdapterAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20Transfer(address(loanToken), address(coreAdapter), amount, coreAdapter));

        vm.expectRevert(ErrorsLib.AdapterAddress.selector);
        initMulticall.multicall(bundle);
    }

    function testTransferZeroAmount() public {
        bundle.push(_erc20Transfer(address(loanToken), RECEIVER, 0, coreAdapter));

        vm.prank(USER);
        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        initMulticall.multicall(bundle);
    }

    function testNativeTransfer(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_transferNativeToAdapter(payable(coreAdapter), amount));
        bundle.push(_nativeTransfer(RECEIVER, amount, coreAdapter));

        deal(address(initMulticall), amount);

        initMulticall.multicall(bundle);

        assertEq(address(coreAdapter).balance, 0, "coreAdapter.balance");
        assertEq(RECEIVER.balance, amount, "RECEIVER.balance");
    }

    function testNativeTransferZeroAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_nativeTransferNoFunding(address(0), amount, coreAdapter));

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        initMulticall.multicall(bundle);
    }

    function testNativeTransferAdapterAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_nativeTransferNoFunding(address(coreAdapter), amount, coreAdapter));

        vm.expectRevert(ErrorsLib.AdapterAddress.selector);
        initMulticall.multicall(bundle);
    }

    function testNativeTransferZeroAmount() public {
        bundle.push(_nativeTransferNoFunding(RECEIVER, 0, coreAdapter));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        initMulticall.multicall(bundle);
    }
}
