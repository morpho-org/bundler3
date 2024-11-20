// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";

import {ERC20WrapperMock, ERC20Wrapper, IERC20} from "../../src/mocks/ERC20WrapperMock.sol";

import "./helpers/ForkTest.sol";

import {Wrapper} from "../../lib/morpho-token-upgradeable/src/Wrapper.sol";

interface ILegacyMorphoToken is IERC20 {
    function owner() external view returns (address);
    function setUserRole(address user, uint8 role, bool enabled) external;
}

contract MorphoWrapperModuleForkTest is ForkTest {
    ERC20WrapperMock internal loanWrapper;
    Wrapper internal wrapper;
    ILegacyMorphoToken internal legacyToken;
    ERC20 internal newToken;

    function setUp() public override {
        super.setUp();

        wrapper = Wrapper(MORPHO_TOKEN_WRAPPER);
        legacyToken = ILegacyMorphoToken(wrapper.LEGACY_MORPHO());
        newToken = ERC20(wrapper.NEW_MORPHO());

        vm.prank(legacyToken.owner());
        legacyToken.setUserRole(address(wrapper), 0, true);
    }

    function testMorphoWrapperDepositFor(uint256 amount, address receiver) public {
        vm.assume(receiver != address(0));
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        deal(address(legacyToken), address(genericModule1), amount);
        bundle.push(_erc20WrapperDepositFor(address(wrapper), address(receiver), amount));

        bundler.multicall(bundle);

        assertEq(legacyToken.balanceOf(address(genericModule1)), 0, "legacyToken.balanceOf(genericModule1)");
        assertEq(newToken.balanceOf(receiver), amount, "newToken.balanceOf(receiver)");
    }

    function testErc20WrapperWithdrawToSomeOnMorphoWrapper(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        deal(address(newToken), address(genericModule1), amount);
        deal(address(legacyToken), address(wrapper), amount);

        bundle.push(_erc20WrapperWithdrawTo(address(wrapper), address(genericModule1), amount));

        bundler.multicall(bundle);
        assertEq(legacyToken.balanceOf(address(wrapper)), 0, "legacyToken.balanceOf(wrapper)");
        assertEq(legacyToken.balanceOf(address(genericModule1)), amount, "legacyToken.balanceOf(genericModule1)");
        assertEq(newToken.balanceOf(address(genericModule1)), 0, "newToken.balanceOf(genericModule1)");
    }

    function testErc20WrapperWithdrawToAllOnMorphoWrapper() public {
        bundle.push(_erc20WrapperWithdrawTo(address(wrapper), RECEIVER, type(uint256).max));

        vm.expectRevert();
        bundler.multicall(bundle);
    }

    function testMorphoWrapperWithdrawToAll() public {
        bundle.push(_morphoWrapperWithdrawTo(RECEIVER, type(uint256).max));

        vm.expectRevert();
        bundler.multicall(bundle);
    }

    function testMorphoWrapperWithdrawToSome(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        deal(address(newToken), address(genericModule1), amount);
        deal(address(legacyToken), address(wrapper), amount);

        bundle.push(_morphoWrapperWithdrawTo(RECEIVER, amount));

        bundler.multicall(bundle);
        assertEq(legacyToken.balanceOf(address(genericModule1)), 0, "legacyToken.balanceOf(genericModule1)");
        assertEq(newToken.balanceOf(address(genericModule1)), 0, "newToken.balanceOf(genericModule1)");
        assertEq(legacyToken.balanceOf(RECEIVER), amount, "legacyToken.balanceOf(RECEIVER)");
    }

    function testMorphoWrapperWithdrawToAccountZeroAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_morphoWrapperWithdrawTo(address(0), amount));

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        bundler.multicall(bundle);
    }

    function testMorphoWrapperWithdrawToZeroAmount() public {
        bundle.push(_morphoWrapperWithdrawTo(RECEIVER, 0));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        bundler.multicall(bundle);
    }

    function testErc20WrapperWithdrawToUnauthorized(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.UnauthorizedSender.selector, address(this)));
        ethereumModule1.morphoWrapperWithdrawTo(RECEIVER, amount);
    }

    function testErc20WrapperWithdrawToFailed(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        deal(address(newToken), address(genericModule1), amount);
        deal(address(legacyToken), address(wrapper), amount);

        bundle.push(_morphoWrapperWithdrawTo(RECEIVER, amount));

        vm.mockCall(address(wrapper), abi.encodeWithSelector(ERC20Wrapper.withdrawTo.selector), abi.encode(false));

        vm.expectRevert(ErrorsLib.WithdrawFailed.selector);
        bundler.multicall(bundle);
    }

    /* MORPHO WRAPPER ACTIONS */
    function _morphoWrapperWithdrawTo(address receiver, uint256 amount) internal view returns (Call memory) {
        return _call(genericModule1, abi.encodeCall(EthereumModule1.morphoWrapperWithdrawTo, (receiver, amount)));
    }
}
