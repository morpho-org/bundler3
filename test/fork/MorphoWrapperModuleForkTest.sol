// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";

import {ERC20WrapperMock, ERC20Wrapper} from "../../src/mocks/ERC20WrapperMock.sol";

import "./helpers/ForkTest.sol";

interface SemiTransferableToken {
    function owner() external view returns (address);
    function setUserRole(address, uint8, bool) external;
}

contract MorphoWrapperModuleForkTest is ForkTest {
    using BundlerLib for Bundler;

    address internal MORPHO_WRAPPER = getAddress("MORPHO_WRAPPER");
    address internal MORPHO_TOKEN_LEGACY = getAddress("MORPHO_TOKEN_LEGACY");
    address internal MORPHO_TOKEN = getAddress("MORPHO_TOKEN");

    function setUp() public override {
        super.setUp();
        if (block.chainid != 1) return;

        vm.prank(SemiTransferableToken(MORPHO_TOKEN_LEGACY).owner());
        SemiTransferableToken(MORPHO_TOKEN_LEGACY).setUserRole(MORPHO_WRAPPER, 0, true);
    }

    function testMorphoWrapperWithdrawToAccountZeroAddress(uint256 amount) public onlyEthereum {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_morphoWrapperWithdrawTo(address(0), amount));

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        bundler.multicall(bundle);
    }

    function testMorphoWrapperWithdrawToZeroAmount() public onlyEthereum {
        bundle.push(_morphoWrapperWithdrawTo(RECEIVER, 0));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        bundler.multicall(bundle);
    }

    function testMorphoWrapperWithdrawToUnauthorized(uint256 amount) public onlyEthereum {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.UnauthorizedSender.selector, address(this)));
        ethereumModule1.morphoWrapperWithdrawTo(RECEIVER, amount);
    }

    function testMorphoWrapperWithdrawToFailed(uint256 amount) public onlyEthereum {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        deal(MORPHO_TOKEN, address(genericModule1), amount);
        deal(MORPHO_TOKEN_LEGACY, MORPHO_WRAPPER, amount);

        bundle.push(_morphoWrapperWithdrawTo(RECEIVER, amount));

        vm.mockCall(MORPHO_WRAPPER, abi.encodeWithSelector(ERC20Wrapper.withdrawTo.selector), abi.encode(false));

        vm.expectRevert(ErrorsLib.WithdrawFailed.selector);
        bundler.multicall(bundle);
    }

    function testMorphoWrapperWithdrawTo(uint256 amount) public onlyEthereum {
        vm.prank(SemiTransferableToken(MORPHO_TOKEN_LEGACY).owner());
        SemiTransferableToken(MORPHO_TOKEN_LEGACY).setUserRole(MORPHO_WRAPPER, 0, true);

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        deal(MORPHO_TOKEN, address(genericModule1), amount);
        deal(MORPHO_TOKEN_LEGACY, MORPHO_WRAPPER, amount);

        uint256 wrapperLegacyBalanceBefore = ERC20(MORPHO_TOKEN_LEGACY).balanceOf(MORPHO_WRAPPER);
        uint256 wrapperBalanceBefore = ERC20(MORPHO_TOKEN).balanceOf(MORPHO_WRAPPER);

        bundle.push(_morphoWrapperWithdrawTo(RECEIVER, amount));

        bundler.multicall(bundle);

        assertEq(ERC20(MORPHO_TOKEN).balanceOf(address(genericModule1)), 0, "morpho.balanceOf(genericModule1)");
        assertEq(
            ERC20(MORPHO_TOKEN).balanceOf(MORPHO_WRAPPER),
            wrapperBalanceBefore + amount,
            "morphoToken.balanceOf(morphoWrapper)"
        );

        assertEq(ERC20(MORPHO_TOKEN_LEGACY).balanceOf(RECEIVER), amount, "morphoTokenLegacy.balanceOf(receiver)");
        assertEq(
            ERC20(MORPHO_TOKEN_LEGACY).balanceOf(MORPHO_WRAPPER),
            wrapperLegacyBalanceBefore - amount,
            "morphoTokenLegacy.balanceOf(morphoWrapper)"
        );
    }

    /* MORPHO WRAPPER ACTIONS */

    function _morphoWrapperWithdrawTo(address receiver, uint256 amount) internal view returns (Call memory) {
        return _call(genericModule1, abi.encodeCall(EthereumModule1.morphoWrapperWithdrawTo, (receiver, amount)));
    }
}
