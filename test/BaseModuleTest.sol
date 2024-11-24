// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";

import "./helpers/LocalTest.sol";

contract BaseModuleLocalTest is LocalTest {
    using BundlerLib for Bundler;

    BaseModule baseModule;

    function setUp() public override {
        super.setUp();
        baseModule = new BaseModule(address(bundler));
    }

    function testTransfer(uint256 amount) public {
        amount = bound(amount, 0, MAX_AMOUNT);

        bundle.push(_erc20Transfer(address(loanToken), RECEIVER, amount, baseModule));

        loanToken.setBalance(address(baseModule), amount);

        bundler.multicall(bundle);

        assertEq(loanToken.balanceOf(address(baseModule)), 0, "loan.balanceOf(baseModule)");
        assertEq(loanToken.balanceOf(RECEIVER), amount, "loan.balanceOf(RECEIVER)");
    }

    function testTranferZeroAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20Transfer(address(loanToken), address(0), amount, baseModule));

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        bundler.multicall(bundle);
    }

    function testTranferModuleAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20Transfer(address(loanToken), address(baseModule), amount, baseModule));

        vm.expectRevert(ErrorsLib.ModuleAddress.selector);
        bundler.multicall(bundle);
    }

    function testNativeTransfer(uint256 amount) public {
        amount = bound(amount, 0, MAX_AMOUNT);

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

    function testTransferTokenZero(uint256 amount, address recipient) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20Transfer(address(0), recipient, amount, baseModule));

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        bundler.multicall(bundle);
    }
}
