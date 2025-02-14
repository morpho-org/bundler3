// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";

import {ERC20WrapperMock, ERC20Wrapper} from "./helpers/mocks/ERC20WrapperMock.sol";

import "./helpers/LocalTest.sol";

contract ERC20WrapperAdapterLocalTest is LocalTest {
    ERC20WrapperMock internal loanWrapper;

    function setUp() public override {
        super.setUp();

        loanWrapper = new ERC20WrapperMock(loanToken, "Wrapped Loan Token", "WLT");
    }

    function testErc20WrapperDepositFor(uint256 amount, address initiator) public {
        vm.assume(initiator != address(0));
        vm.assume(initiator != address(loanWrapper));
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20WrapperDepositFor(address(loanWrapper), amount));

        deal(address(loanToken), address(erc20WrapperAdapter), amount);

        vm.prank(initiator);
        bundler3.multicall(bundle);

        assertEq(loanToken.balanceOf(address(erc20WrapperAdapter)), 0, "loan.balanceOf(erc20WrapperAdapter)");
        assertEq(loanWrapper.balanceOf(initiator), amount, "loanWrapper.balanceOf(initiator)");
        assertEq(
            loanToken.allowance(address(erc20WrapperAdapter), address(loanWrapper)),
            0,
            "loanToken.allowance(erc20WrapperAdapter, loanWrapper)"
        );
    }

    function testErc20WrapperDepositForZeroAmount(address initiator) public {
        bundle.push(_erc20WrapperDepositFor(address(loanWrapper), 0));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        vm.prank(initiator);
        bundler3.multicall(bundle);
    }

    function testErc20WrapperWithdrawTo(address initiator, uint256 amount) public {
        vm.assume(initiator != address(0));
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        deal(address(loanWrapper), address(erc20WrapperAdapter), amount);
        deal(address(loanToken), address(loanWrapper), amount);

        bundle.push(_erc20WrapperWithdrawTo(address(loanWrapper), RECEIVER, amount));

        vm.startPrank(initiator);
        IERC20(loanWrapper).approve(address(erc20WrapperAdapter), amount);
        bundler3.multicall(bundle);
        vm.stopPrank();

        assertEq(loanWrapper.balanceOf(address(erc20WrapperAdapter)), 0, "loanWrapper.balanceOf(erc20WrapperAdapter)");
        assertEq(loanToken.balanceOf(RECEIVER), amount, "loan.balanceOf(RECEIVER)");
    }

    function testErc20WrapperWithdrawToAll(address initiator, uint256 amount) public {
        vm.assume(initiator != address(0));
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        deal(address(loanWrapper), address(erc20WrapperAdapter), amount);
        deal(address(loanToken), address(loanWrapper), amount);

        bundle.push(_erc20WrapperWithdrawTo(address(loanWrapper), RECEIVER, type(uint256).max));

        vm.startPrank(initiator);
        IERC20(loanWrapper).approve(address(erc20WrapperAdapter), amount);
        bundler3.multicall(bundle);
        vm.stopPrank();

        assertEq(loanWrapper.balanceOf(address(erc20WrapperAdapter)), 0, "loanWrapper.balanceOf(erc20WrapperAdapter)");
        assertEq(loanToken.balanceOf(RECEIVER), amount, "loan.balanceOf(RECEIVER)");
    }

    function testErc20WrapperWithdrawToAccountZeroAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20WrapperWithdrawTo(address(loanWrapper), address(0), amount));

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        bundler3.multicall(bundle);
    }

    function testErc20WrapperWithdrawToZeroAmount() public {
        bundle.push(_erc20WrapperWithdrawTo(address(loanWrapper), RECEIVER, 0));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        bundler3.multicall(bundle);
    }

    function testErc20WrapperDepositForOnlyBundler3(uint256 amount, address initiator) public {
        vm.assume(initiator != address(bundler3));
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(ErrorsLib.UnauthorizedSender.selector);
        vm.prank(initiator);
        erc20WrapperAdapter.erc20WrapperDepositFor(address(loanWrapper), amount);
    }

    function testErc20WrapperWithdrawToOnlyBundler3(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(ErrorsLib.UnauthorizedSender.selector);
        erc20WrapperAdapter.erc20WrapperWithdrawTo(address(loanWrapper), RECEIVER, amount);
    }

    function testErc20WrapperDepositToFailed(uint256 amount, address initiator) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);
        deal(address(loanToken), address(erc20WrapperAdapter), amount);

        bundle.push(_erc20WrapperDepositFor(address(loanWrapper), amount));

        vm.mockCall(address(loanWrapper), abi.encodeWithSelector(ERC20Wrapper.depositFor.selector), abi.encode(false));

        vm.expectRevert(ErrorsLib.DepositFailed.selector);
        vm.prank(initiator);
        bundler3.multicall(bundle);
    }

    function testErc20WrapperWithdrawToFailed(address initiator, uint256 amount) public {
        vm.assume(initiator != address(0));
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);
        deal(address(loanWrapper), address(erc20WrapperAdapter), amount);
        deal(address(loanToken), address(loanWrapper), amount);

        bundle.push(_erc20WrapperWithdrawTo(address(loanWrapper), RECEIVER, amount));

        vm.mockCall(address(loanWrapper), abi.encodeWithSelector(ERC20Wrapper.withdrawTo.selector), abi.encode(false));

        vm.startPrank(initiator);
        IERC20(loanWrapper).approve(address(erc20WrapperAdapter), amount);
        vm.expectRevert(ErrorsLib.WithdrawFailed.selector);
        bundler3.multicall(bundle);
        vm.stopPrank();
    }
}
