// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";

import "./helpers/LocalTest.sol";

contract ConcreteBaseModule is BaseModule {
    constructor(address bundler) BaseModule(bundler) {}
}

contract BaseModuleLocalTest is LocalTest {
    BaseModule internal baseModule;

    function setUp() public override {
        super.setUp();
        baseModule = new ConcreteBaseModule(address(bundler));
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
}
