// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";

import "./helpers/LocalTest.sol";

contract ConcreteCoreModule is CoreModule {
    constructor(address bundler) CoreModule(bundler) {}
}

contract CoreModuleLocalTest is LocalTest {
    CoreModule internal coreModule;

    function setUp() public override {
        super.setUp();
        coreModule = new ConcreteCoreModule(address(bundler));
    }

    function testTransfer(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20Transfer(address(loanToken), RECEIVER, amount, coreModule));

        deal(address(loanToken), address(coreModule), amount);

        bundler.multicall(bundle);

        assertEq(loanToken.balanceOf(address(coreModule)), 0, "loan.balanceOf(coreModule)");
        assertEq(loanToken.balanceOf(RECEIVER), amount, "loan.balanceOf(RECEIVER)");
    }

    function testTransferZeroAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20Transfer(address(loanToken), address(0), amount, coreModule));

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        bundler.multicall(bundle);
    }

    function testTransferModuleAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20Transfer(address(loanToken), address(coreModule), amount, coreModule));

        vm.expectRevert(ErrorsLib.ModuleAddress.selector);
        bundler.multicall(bundle);
    }

    function testTransferZeroAmount() public {
        bundle.push(_erc20Transfer(address(loanToken), RECEIVER, 0, coreModule));

        vm.prank(USER);
        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        bundler.multicall(bundle);
    }

    function testNativeTransfer(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_transferNativeToModule(payable(coreModule), amount));
        bundle.push(_nativeTransfer(RECEIVER, amount, coreModule));

        deal(address(bundler), amount);

        bundler.multicall(bundle);

        assertEq(address(coreModule).balance, 0, "coreModule.balance");
        assertEq(RECEIVER.balance, amount, "RECEIVER.balance");
    }

    function testNativeTransferZeroAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_nativeTransferNoFunding(address(0), amount, coreModule));

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        bundler.multicall(bundle);
    }

    function testNativeTransferModuleAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_nativeTransferNoFunding(address(coreModule), amount, coreModule));

        vm.expectRevert(ErrorsLib.ModuleAddress.selector);
        bundler.multicall(bundle);
    }

    function testNativeTransferZeroAmount() public {
        bundle.push(_nativeTransferNoFunding(RECEIVER, 0, coreModule));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        bundler.multicall(bundle);
    }
}
