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
        vm.assume(initiator != address(loanWrapper));
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20WrapperDepositFor(address(loanWrapper), amount));

        deal(address(loanToken), address(generalAdapter1), amount);

        vm.prank(initiator);
        bundler3.multicall(bundle);

        assertEq(loanToken.balanceOf(address(generalAdapter1)), 0, "loan.balanceOf(generalAdapter1)");
        assertEq(loanWrapper.balanceOf(initiator), amount, "loanWrapper.balanceOf(initiator)");
        assertEq(
            loanToken.allowance(address(generalAdapter1), address(loanWrapper)),
            0,
            "loanToken.allowance(generalAdapter1, loanWrapper)"
        );
    }

    function testErc20WrapperDepositForZeroAmount(address initiator) public {
        bundle.push(_erc20WrapperDepositFor(address(loanWrapper), 0));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        vm.prank(initiator);
        bundler3.multicall(bundle);
    }

    function testErc20WrapperWithdrawTo(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        deal(address(loanWrapper), address(generalAdapter1), amount);
        deal(address(loanToken), address(loanWrapper), amount);

        bundle.push(_erc20WrapperWithdrawTo(address(loanWrapper), RECEIVER, amount));

        bundler3.multicall(bundle);

        assertEq(loanWrapper.balanceOf(address(generalAdapter1)), 0, "loanWrapper.balanceOf(generalAdapter1)");
        assertEq(loanToken.balanceOf(RECEIVER), amount, "loan.balanceOf(RECEIVER)");
    }

    function testErc20WrapperWithdrawToAll(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        deal(address(loanWrapper), address(generalAdapter1), amount);
        deal(address(loanToken), address(loanWrapper), amount);

        bundle.push(_erc20WrapperWithdrawTo(address(loanWrapper), RECEIVER, type(uint256).max));

        bundler3.multicall(bundle);

        assertEq(loanWrapper.balanceOf(address(generalAdapter1)), 0, "loanWrapper.balanceOf(generalAdapter1)");
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

    function testErc20WrapperDepositForUnauthorized(uint256 amount, address initiator) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(ErrorsLib.UnauthorizedSender.selector);
        vm.prank(initiator);
        generalAdapter1.erc20WrapperDepositFor(address(loanWrapper), amount);
    }

    function testErc20WrapperWithdrawToUnauthorized(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(ErrorsLib.UnauthorizedSender.selector);
        generalAdapter1.erc20WrapperWithdrawTo(address(loanWrapper), RECEIVER, amount);
    }

    function testErc20WrapperDepositToFailed(uint256 amount, address initiator) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);
        deal(address(loanToken), address(generalAdapter1), amount);

        bundle.push(_erc20WrapperDepositFor(address(loanWrapper), amount));

        vm.mockCall(address(loanWrapper), abi.encodeWithSelector(ERC20Wrapper.depositFor.selector), abi.encode(false));

        vm.expectRevert(ErrorsLib.DepositFailed.selector);
        vm.prank(initiator);
        bundler3.multicall(bundle);
    }

    function testErc20WrapperWithdrawToFailed(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);
        deal(address(loanWrapper), address(generalAdapter1), amount);
        deal(address(loanToken), address(loanWrapper), amount);

        bundle.push(_erc20WrapperWithdrawTo(address(loanWrapper), RECEIVER, amount));

        vm.mockCall(address(loanWrapper), abi.encodeWithSelector(ERC20Wrapper.withdrawTo.selector), abi.encode(false));

        vm.expectRevert(ErrorsLib.WithdrawFailed.selector);
        bundler3.multicall(bundle);
    }
}
