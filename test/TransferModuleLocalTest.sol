// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";

import "./helpers/LocalTest.sol";

contract TransferModuleLocalTest is LocalTest {
    function testTransferFrom(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20TransferFrom(address(loanToken), amount));

        loanToken.setBalance(USER, amount);

        vm.startPrank(USER);
        loanToken.approve(address(genericModule1), type(uint256).max);
        bundler.multicall(bundle);
        vm.stopPrank();

        assertEq(loanToken.balanceOf(address(genericModule1)), amount, "loan.balanceOf(genericModule1)");
        assertEq(loanToken.balanceOf(USER), 0, "loan.balanceOf(USER)");
    }

    function testTransferFromUnauthorized(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.UnauthorizedSender.selector, address(this)));
        genericModule1.erc20TransferFrom(address(loanToken), RECEIVER, amount);
    }

    function testTranferFromZeroAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20TransferFrom(address(0), amount));

        vm.prank(USER);
        vm.expectRevert();
        bundler.multicall(bundle);
    }

    function testTranferFromZeroAmount() public {
        bundle.push(_erc20TransferFrom(address(loanToken), 0));

        vm.prank(USER);
        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        bundler.multicall(bundle);
    }

    function testApproveMaxTo(address spender) public {
        vm.assume(spender != address(0));
        bundle.push(_erc20ApproveMaxTo(address(loanToken), spender));

        vm.prank(USER);
        bundler.multicall(bundle);

        assertEq(
            loanToken.allowance(address(genericModule1), spender),
            type(uint256).max,
            "loan.allowance(spender, genericModule1)"
        );
    }

    function testApproveMaxToZeroAddress() public {
        bundle.push(_erc20ApproveMaxTo(address(loanToken), address(0)));

        vm.prank(USER);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        bundler.multicall(bundle);
    }

    function testApproveMaxToZeroSpender() public {
        bundle.push(_erc20ApproveMaxTo(address(0), address(genericModule1)));

        vm.prank(USER);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        bundler.multicall(bundle);
    }
}
