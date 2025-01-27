// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";

import {ERC20WrapperMock, ERC20Wrapper} from "./helpers/mocks/ERC20WrapperMock.sol";
import {ERC20PermissionedWrapperMock} from "./helpers/mocks/ERC20PermissionedWrapperMock.sol";

import "./helpers/LocalTest.sol";

contract ERC20PermissionedWrapperAdapterLocalTest is LocalTest {
    ERC20WrapperMock internal wrapper;
    ERC20PermissionedWrapperMock internal permissionedWrapper;

    function setUp() public override {
        super.setUp();

        wrapper = new ERC20WrapperMock(loanToken, "Wrapped Token", "WT");
        permissionedWrapper = new ERC20PermissionedWrapperMock(loanToken, "Permissioned Wrapped Token", "PWT");

        permissionedWrapper.updateWhitelist(address(permissionedWrapperAdapter), true);
    }

    function testErc20PermissionedWrapperDeposit(uint256 amount, address initiator) public {
        vm.assume(initiator != address(wrapper));
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20PermissionedWrapperDeposit(address(wrapper), amount));

        deal(address(loanToken), address(permissionedWrapperAdapter), amount);

        vm.prank(initiator);
        bundler3.multicall(bundle);

        assertEq(loanToken.balanceOf(address(permissionedWrapperAdapter)), 0, "loan.balanceOf(permissionedWrapperAdapter)");
        assertEq(wrapper.balanceOf(initiator), amount, "wrapper.balanceOf(initiator)");
        assertEq(
            loanToken.allowance(address(permissionedWrapperAdapter), address(wrapper)),
            0,
            "loanToken.allowance(permissionedWrapperAdapter, wrapper)"
        );
    }

    function testInitiatorNotWhitelistedDeposit(uint amount, address initiator) public {
        vm.assume(initiator != address(0));
        vm.assume(initiator != address(wrapper));
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20PermissionedWrapperDeposit(address(permissionedWrapper), amount));

        deal(address(loanToken), address(permissionedWrapperAdapter), amount);

        vm.prank(initiator);
        vm.expectRevert("ERC20WrapperMock: non-whitelisted to address");
        bundler3.multicall(bundle);
    }

    function testErc20PermissionedWrapperDepositZeroAmount() public {
        bundle.push(_erc20PermissionedWrapperDeposit(address(wrapper), 0));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        bundler3.multicall(bundle);
    }

    function testErc20PermissionedWrapperWithdrawTo(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        deal(address(wrapper), address(permissionedWrapperAdapter), amount);
        deal(address(loanToken), address(wrapper), amount);

        bundle.push(_erc20PermissionedWrapperWithdrawTo(address(wrapper), RECEIVER, amount));

        bundler3.multicall(bundle);

        assertEq(wrapper.balanceOf(address(permissionedWrapperAdapter)), 0, "wrapper.balanceOf(permissionedWrapperAdapter)");
        assertEq(loanToken.balanceOf(RECEIVER), amount, "loan.balanceOf(RECEIVER)");
    }

    function testErc20PermissionedWrapperWithdrawToAll(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        deal(address(wrapper), address(permissionedWrapperAdapter), amount);
        deal(address(loanToken), address(wrapper), amount);

        bundle.push(_erc20PermissionedWrapperWithdrawTo(address(wrapper), RECEIVER, type(uint256).max));

        bundler3.multicall(bundle);

        assertEq(wrapper.balanceOf(address(permissionedWrapperAdapter)), 0, "wrapper.balanceOf(permissionedWrapperAdapter)");
        assertEq(loanToken.balanceOf(RECEIVER), amount, "loan.balanceOf(RECEIVER)");
    }

    function testErc20PermissionedWrapperWithdrawToAccountZeroAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20PermissionedWrapperWithdrawTo(address(wrapper), address(0), amount));

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        bundler3.multicall(bundle);
    }

    function testErc20PermissionedWrapperWithdrawToZeroAmount() public {
        bundle.push(_erc20PermissionedWrapperWithdrawTo(address(wrapper), RECEIVER, 0));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        bundler3.multicall(bundle);
    }

    function testErc20PermissionedWrapperDepositUnauthorized(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(ErrorsLib.UnauthorizedSender.selector);
        permissionedWrapperAdapter.erc20PermissionedWrapperDeposit(address(wrapper), amount);
    }

    function testErc20PermissionedWrapperWithdrawToUnauthorized(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(ErrorsLib.UnauthorizedSender.selector);
        permissionedWrapperAdapter.erc20PermissionedWrapperWithdrawTo(address(wrapper), RECEIVER, amount);
    }

    function testErc20PermissionedWrapperDepositToFailed(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);
        deal(address(loanToken), address(permissionedWrapperAdapter), amount);

        bundle.push(_erc20PermissionedWrapperDeposit(address(wrapper), amount));

        vm.mockCall(address(wrapper), abi.encodeWithSelector(ERC20Wrapper.depositFor.selector), abi.encode(false));

        vm.expectRevert(ErrorsLib.DepositFailed.selector);
        bundler3.multicall(bundle);
    }

    function testErc20PermissionedWrapperWithdrawToFailed(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);
        deal(address(wrapper), address(permissionedWrapperAdapter), amount);
        deal(address(loanToken), address(wrapper), amount);

        bundle.push(_erc20PermissionedWrapperWithdrawTo(address(wrapper), RECEIVER, amount));

        vm.mockCall(address(wrapper), abi.encodeWithSelector(ERC20Wrapper.withdrawTo.selector), abi.encode(false));

        vm.expectRevert(ErrorsLib.WithdrawFailed.selector);
        bundler3.multicall(bundle);
    }
}
