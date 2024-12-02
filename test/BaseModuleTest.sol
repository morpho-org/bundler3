// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";

import "./helpers/LocalTest.sol";

contract BaseModuleLocalTest is LocalTest {
    IBaseModule internal baseModule;

    function setUp() public override {
        super.setUp();
        baseModule = IBaseModule(payable(deployCode("BaseModuleMock.sol", abi.encode(bundler))));
    }

    function testTransfer(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20Transfer(address(loanToken), RECEIVER, amount, baseModule));

        deal(address(loanToken), address(baseModule), amount);

        bundler.multicall(bundle);

        assertEq(loanToken.balanceOf(address(baseModule)), 0, "loan.balanceOf(baseModule)");
        assertEq(loanToken.balanceOf(RECEIVER), amount, "loan.balanceOf(RECEIVER)");
    }

    function testTransferZeroAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20Transfer(address(loanToken), address(0), amount, baseModule));

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        bundler.multicall(bundle);
    }

    function testTransferModuleAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20Transfer(address(loanToken), address(baseModule), amount, baseModule));

        vm.expectRevert(ErrorsLib.ModuleAddress.selector);
        bundler.multicall(bundle);
    }

    function testTransferZeroAmount() public {
        bundle.push(_erc20Transfer(address(loanToken), RECEIVER, 0, baseModule));

        vm.prank(USER);
        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        bundler.multicall(bundle);
    }

    function testNativeTransfer(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_sendNativeToModule(payable(baseModule), amount));
        bundle.push(_nativeTransfer(RECEIVER, amount, baseModule));

        deal(address(bundler), amount);

        bundler.multicall(bundle);

        assertEq(address(baseModule).balance, 0, "baseModule.balance");
        assertEq(RECEIVER.balance, amount, "RECEIVER.balance");
    }

    function testNativeTransferZeroAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_nativeTransferNoFunding(address(0), amount, baseModule));

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        bundler.multicall(bundle);
    }

    function testNativeTransferModuleAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_nativeTransferNoFunding(address(baseModule), amount, baseModule));

        vm.expectRevert(ErrorsLib.ModuleAddress.selector);
        bundler.multicall(bundle);
    }

    function testNativeTransferZeroAmount() public {
        bundle.push(_nativeTransferNoFunding(RECEIVER, 0, baseModule));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        bundler.multicall(bundle);
    }
}
