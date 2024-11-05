// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../../src/libraries/ErrorsLib.sol" as ErrorsLib;

import "./helpers/LocalTest.sol";

contract TransferBundlerLocalTest is LocalTest {
    function testTransferFrom(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20TransferFrom(address(loanToken), amount));

        loanToken.setBalance(USER, amount);

        vm.startPrank(USER);
        loanToken.approve(address(genericBundler1), type(uint256).max);
        hub.multicall(bundle);
        vm.stopPrank();

        assertEq(loanToken.balanceOf(address(genericBundler1)), amount, "loan.balanceOf(genericBundler1)");
        assertEq(loanToken.balanceOf(USER), 0, "loan.balanceOf(USER)");
    }

    function testTransferFromUnauthorized(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(ErrorsLib.UnauthorizedSender.selector);
        genericBundler1.erc20TransferFrom(address(loanToken), RECEIVER, amount);
    }

    function testTranferFromZeroAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20TransferFrom(address(0), amount));

        vm.prank(USER);
        vm.expectRevert();
        hub.multicall(bundle);
    }

    function testTranferFromZeroAmount() public {
        bundle.push(_erc20TransferFrom(address(loanToken), 0));

        vm.prank(USER);
        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        hub.multicall(bundle);
    }
}
