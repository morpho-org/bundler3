// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";

import {ERC20WrapperMock, ERC20Wrapper} from "../helpers/mocks/ERC20WrapperMock.sol";

import "./helpers/ForkTest.sol";

interface SemiTransferableToken {
    function owner() external view returns (address);
    function setUserRole(address, uint8, bool) external;
}

contract MorphoWrapperAdapterForkTest is ForkTest {
    address internal immutable MORPHO_WRAPPER = getAddress("MORPHO_WRAPPER");
    address internal immutable MORPHO_TOKEN_LEGACY = getAddress("MORPHO_TOKEN_LEGACY");
    address internal immutable MORPHO_TOKEN = getAddress("MORPHO_TOKEN");

    function setUp() public override {
        super.setUp();
        if (block.chainid != 1) return;

        vm.prank(SemiTransferableToken(MORPHO_TOKEN_LEGACY).owner());
        SemiTransferableToken(MORPHO_TOKEN_LEGACY).setUserRole(MORPHO_WRAPPER, 0, true);
    }

    function testMorphoWrapperDepositFor(uint256 amount, address initiator) public onlyEthereum {
        vm.assume(initiator != address(0));
        vm.assume(initiator != address(MORPHO_TOKEN));
        vm.assume(initiator != address(MORPHO_WRAPPER));
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_morphoWrapperDepositFor(initiator, amount));

        deal(address(MORPHO_TOKEN_LEGACY), address(generalAdapter1), amount);

        vm.prank(initiator);
        bundler3.multicall(bundle);

        assertEq(IERC20(MORPHO_TOKEN_LEGACY).balanceOf(address(generalAdapter1)), 0, "loan.balanceOf(generalAdapter1)");
        assertEq(IERC20(MORPHO_TOKEN).balanceOf(initiator), amount, "MORPHO_TOKEN.balanceOf(initiator)");
        assertEq(
            IERC20(MORPHO_TOKEN_LEGACY).allowance(address(generalAdapter1), address(MORPHO_TOKEN)),
            0,
            "MORPHO_TOKEN_LEGACY.allowance(generalAdapter1, MORPHO_TOKEN)"
        );
    }

    function testMorphoWrapperDepositForZeroAmount(address initiator) public onlyEthereum {
        bundle.push(_morphoWrapperDepositFor(address(MORPHO_TOKEN), 0));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        vm.prank(initiator);
        bundler3.multicall(bundle);
    }

    function testMorphoWrapperDepositForUnauthorized(uint256 amount, address initiator) public onlyEthereum {
        vm.assume(initiator != address(bundler3));
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(ErrorsLib.UnauthorizedSender.selector);
        vm.prank(initiator);
        ethereumGeneralAdapter1.morphoWrapperDepositFor(address(MORPHO_TOKEN), amount);
    }

    function testMorphoWrapperDepositForFailed(uint256 amount, address initiator) public onlyEthereum {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);
        deal(address(MORPHO_TOKEN_LEGACY), address(generalAdapter1), amount);

        bundle.push(_morphoWrapperDepositFor(address(MORPHO_TOKEN), amount));

        vm.mockCall(
            address(MORPHO_WRAPPER), abi.encodeWithSelector(ERC20Wrapper.depositFor.selector), abi.encode(false)
        );

        vm.expectRevert(ErrorsLib.DepositFailed.selector);
        vm.prank(initiator);
        bundler3.multicall(bundle);
    }

    function testMorphoWrapperWithdrawToAccountZeroAddress(uint256 amount) public onlyEthereum {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_morphoWrapperWithdrawTo(address(0), amount));

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        bundler3.multicall(bundle);
    }

    function testMorphoWrapperWithdrawToZeroAmount() public onlyEthereum {
        bundle.push(_morphoWrapperWithdrawTo(RECEIVER, 0));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        bundler3.multicall(bundle);
    }

    function testMorphoWrapperWithdrawToUnauthorized(uint256 amount) public onlyEthereum {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(ErrorsLib.UnauthorizedSender.selector);
        ethereumGeneralAdapter1.morphoWrapperWithdrawTo(RECEIVER, amount);
    }

    function testMorphoWrapperWithdrawToFailed(uint256 amount) public onlyEthereum {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        deal(MORPHO_TOKEN, address(generalAdapter1), amount);
        deal(MORPHO_TOKEN_LEGACY, MORPHO_WRAPPER, amount);

        bundle.push(_morphoWrapperWithdrawTo(RECEIVER, amount));

        vm.mockCall(MORPHO_WRAPPER, abi.encodeWithSelector(ERC20Wrapper.withdrawTo.selector), abi.encode(false));

        vm.expectRevert(ErrorsLib.WithdrawFailed.selector);
        bundler3.multicall(bundle);
    }

    function testMorphoWrapperWithdrawTo(uint256 amount) public onlyEthereum {
        vm.prank(SemiTransferableToken(MORPHO_TOKEN_LEGACY).owner());
        SemiTransferableToken(MORPHO_TOKEN_LEGACY).setUserRole(MORPHO_WRAPPER, 0, true);

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        deal(MORPHO_TOKEN, address(generalAdapter1), amount);
        deal(MORPHO_TOKEN_LEGACY, MORPHO_WRAPPER, amount);

        uint256 wrapperLegacyBalanceBefore = IERC20(MORPHO_TOKEN_LEGACY).balanceOf(MORPHO_WRAPPER);
        uint256 wrapperBalanceBefore = IERC20(MORPHO_TOKEN).balanceOf(MORPHO_WRAPPER);

        bundle.push(_morphoWrapperWithdrawTo(RECEIVER, amount));

        bundler3.multicall(bundle);

        assertEq(IERC20(MORPHO_TOKEN).balanceOf(address(generalAdapter1)), 0, "morpho.balanceOf(generalAdapter1)");
        assertEq(
            IERC20(MORPHO_TOKEN).balanceOf(MORPHO_WRAPPER),
            wrapperBalanceBefore + amount,
            "morphoToken.balanceOf(morphoWrapper)"
        );

        assertEq(IERC20(MORPHO_TOKEN_LEGACY).balanceOf(RECEIVER), amount, "morphoTokenLegacy.balanceOf(receiver)");
        assertEq(
            IERC20(MORPHO_TOKEN_LEGACY).balanceOf(MORPHO_WRAPPER),
            wrapperLegacyBalanceBefore - amount,
            "morphoTokenLegacy.balanceOf(morphoWrapper)"
        );
    }

    /* MORPHO WRAPPER ACTIONS */

    function _morphoWrapperDepositFor(address receiver, uint256 amount) internal view returns (Call memory) {
        return
            _call(generalAdapter1, abi.encodeCall(EthereumGeneralAdapter1.morphoWrapperDepositFor, (receiver, amount)));
    }

    function _morphoWrapperWithdrawTo(address receiver, uint256 amount) internal view returns (Call memory) {
        return
            _call(generalAdapter1, abi.encodeCall(EthereumGeneralAdapter1.morphoWrapperWithdrawTo, (receiver, amount)));
    }
}
