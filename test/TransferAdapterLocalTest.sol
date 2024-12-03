// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";

import "./helpers/LocalTest.sol";

contract TransferAdapterLocalTest is LocalTest {
    function testTransferFrom(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20TransferFrom(address(loanToken), amount));

        deal(address(loanToken), USER, amount);

        vm.startPrank(USER);
        loanToken.approve(address(generalAdapter1), type(uint256).max);
        multiexec.multicall(bundle);
        vm.stopPrank();

        assertEq(loanToken.balanceOf(address(generalAdapter1)), amount, "loan.balanceOf(generalAdapter1)");
        assertEq(loanToken.balanceOf(USER), 0, "loan.balanceOf(USER)");
    }

    function testTransferFromZeroAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20TransferFrom(address(loanToken), address(0), amount));

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        multiexec.multicall(bundle);
    }

    function testTransferFromUnauthorized(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(ErrorsLib.UnauthorizedSender.selector);
        generalAdapter1.erc20TransferFrom(address(loanToken), RECEIVER, amount);
    }

    function testTransferFromZeroAmount() public {
        bundle.push(_erc20TransferFrom(address(loanToken), 0));

        vm.prank(USER);
        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        multiexec.multicall(bundle);
    }
}
