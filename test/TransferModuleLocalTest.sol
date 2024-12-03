// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";

import "./helpers/LocalTest.sol";

contract TransferModuleLocalTest is LocalTest {
    function testTransferFrom(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20TransferFrom(address(loanToken), amount));

        deal(address(loanToken), USER, amount);

        vm.startPrank(USER);
        loanToken.approve(address(generalModule1), type(uint256).max);
        bundler.multicall(bundle);
        vm.stopPrank();

        assertEq(loanToken.balanceOf(address(generalModule1)), amount, "loan.balanceOf(generalModule1)");
        assertEq(loanToken.balanceOf(USER), 0, "loan.balanceOf(USER)");
    }

    function testTransferFromZeroAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20TransferFrom(address(loanToken), address(0), amount));

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        bundler.multicall(bundle);
    }

    function testTransferFromUnauthorized(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(ErrorsLib.UnauthorizedSender.selector);
        generalModule1.erc20TransferFrom(address(loanToken), RECEIVER, amount);
    }

    function testTransferFromZeroAmount() public {
        bundle.push(_erc20TransferFrom(address(loanToken), 0));

        vm.prank(USER);
        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        bundler.multicall(bundle);
    }
}
