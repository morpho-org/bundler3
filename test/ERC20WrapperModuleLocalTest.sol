// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";

import {ERC20WrapperMock, ERC20Wrapper} from "../src/mocks/ERC20WrapperMock.sol";

import "./helpers/LocalTest.sol";

contract ERC20WrapperModuleLocalTest is LocalTest {
    using BundlerLib for Bundler;

    ERC20WrapperMock internal loanWrapper;

    function setUp() public override {
        super.setUp();

        loanWrapper = new ERC20WrapperMock(loanToken, "Wrapped Loan Token", "WLT");
    }

    function testErc20WrapperDepositFor(uint256 amount, address receiver) public {
        vm.assume(receiver != address(0));
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20WrapperDepositFor(address(loanWrapper), address(receiver), amount));

        loanToken.setBalance(address(genericModule1), amount);

        bundler.multicall(bundle);

        assertEq(loanToken.balanceOf(address(genericModule1)), 0, "loan.balanceOf(genericModule1)");
        assertEq(loanWrapper.balanceOf(receiver), amount, "loanWrapper.balanceOf(receiver)");
    }

    function testErc20WrapperDepositForZeroAmount() public {
        bundle.push(_erc20WrapperDepositFor(address(loanWrapper), address(RECEIVER), 0));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        bundler.multicall(bundle);
    }

    function testErc20WrapperWithdrawTo(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        loanWrapper.setBalance(address(genericModule1), amount);
        loanToken.setBalance(address(loanWrapper), amount);

        bundle.push(_erc20WrapperWithdrawTo(address(loanWrapper), RECEIVER, amount));

        bundler.multicall(bundle);

        assertEq(loanWrapper.balanceOf(address(genericModule1)), 0, "loanWrapper.balanceOf(genericModule1)");
        assertEq(loanToken.balanceOf(RECEIVER), amount, "loan.balanceOf(RECEIVER)");
    }

    function testErc20WrapperWithdrawToAll(uint256 amount, uint256 inputAmount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);
        inputAmount = bound(inputAmount, amount, type(uint256).max);

        loanWrapper.setBalance(address(genericModule1), amount);
        loanToken.setBalance(address(loanWrapper), amount);

        bundle.push(_erc20WrapperWithdrawTo(address(loanWrapper), RECEIVER, inputAmount));

        bundler.multicall(bundle);

        assertEq(loanWrapper.balanceOf(address(genericModule1)), 0, "loanWrapper.balanceOf(genericModule1)");
        assertEq(loanToken.balanceOf(RECEIVER), amount, "loan.balanceOf(RECEIVER)");
    }

    function testErc20WrapperWithdrawToAccountZeroAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20WrapperWithdrawTo(address(loanWrapper), address(0), amount));

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        bundler.multicall(bundle);
    }

    function testErc20WrapperWithdrawToZeroAmount() public {
        bundle.push(_erc20WrapperWithdrawTo(address(loanWrapper), RECEIVER, 0));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        bundler.multicall(bundle);
    }

    function testErc20WrapperDepositForUnauthorized(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.UnauthorizedSender.selector, address(this)));
        genericModule1.erc20WrapperDepositFor(address(loanWrapper), address(RECEIVER), amount);
    }

    function testErc20WrapperWithdrawToUnauthorized(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.UnauthorizedSender.selector, address(this)));
        genericModule1.erc20WrapperWithdrawTo(address(loanWrapper), RECEIVER, amount);
    }

    function testErc20WrapperDepositToFailed(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);
        loanToken.setBalance(address(genericModule1), amount);

        bundle.push(_erc20WrapperDepositFor(address(loanWrapper), address(RECEIVER), amount));

        vm.mockCall(address(loanWrapper), abi.encodeWithSelector(ERC20Wrapper.depositFor.selector), abi.encode(false));

        vm.expectRevert(ErrorsLib.DepositFailed.selector);
        bundler.multicall(bundle);
    }

    function testErc20WrapperWithdrawToFailed(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);
        loanWrapper.setBalance(address(genericModule1), amount);
        loanToken.setBalance(address(loanWrapper), amount);

        bundle.push(_erc20WrapperWithdrawTo(address(loanWrapper), RECEIVER, amount));

        vm.mockCall(address(loanWrapper), abi.encodeWithSelector(ERC20Wrapper.withdrawTo.selector), abi.encode(false));

        vm.expectRevert(ErrorsLib.WithdrawFailed.selector);
        bundler.multicall(bundle);
    }
}
