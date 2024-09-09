// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.26;

import {IWNative} from "./interfaces/IWNative.sol";

import {Math} from "../lib/morpho-utils/src/math/Math.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {SafeTransferLib, ERC20} from "../lib/solmate/src/utils/SafeTransferLib.sol";

import {BaseBundler} from "./BaseBundler.sol";

/// @title WNativeBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Bundler contract managing interactions with network's wrapped native token.
/// @notice "wrapped native" refers to forks of WETH.
abstract contract WNativeBundler is BaseBundler {
    using SafeTransferLib for ERC20;

    /* IMMUTABLES */

    /// @dev The address of the wrapped native token contract.
    address public immutable WRAPPED_NATIVE;

    /* CONSTRUCTOR */

    /// @param wNative The address of the wNative token contract.
    constructor(address wNative) {
        require(wNative != address(0), ErrorsLib.ZERO_ADDRESS);

        WRAPPED_NATIVE = wNative;
    }

    /* FALLBACKS */

    /// @notice Native tokens are received by the bundler and should be used afterwards.
    /// @dev Allows the wrapped native contract to send native tokens to the bundler.
    receive() external payable {}

    /* ACTIONS */

    /// @notice Wraps the given `amount` of the native token to wNative.
    /// @notice Wrapped native tokens are received by the bundler and should be used afterwards.
    /// @dev Initiator must have previously transferred their native tokens to the bundler.
    /// @param amount The amount of native token to wrap. Capped at the bundler's native token balance.
    function wrapNative(uint256 amount) external payable protected {
        amount = Math.min(amount, address(this).balance);

        require(amount != 0, ErrorsLib.ZERO_AMOUNT);

        IWNative(WRAPPED_NATIVE).deposit{value: amount}();
    }

    /// @notice Unwraps the given `amount` of wNative to the native token.
    /// @notice Unwrapped native tokens are received by the bundler and should be used afterwards.
    /// @dev Initiator must have previously transferred their wrapped native tokens to the bundler.
    /// @param amount The amount of wrapped native token to unwrap. Capped at the bundler's wNative balance.
    function unwrapNative(uint256 amount) external payable protected {
        amount = Math.min(amount, ERC20(WRAPPED_NATIVE).balanceOf(address(this)));

        require(amount != 0, ErrorsLib.ZERO_AMOUNT);

        IWNative(WRAPPED_NATIVE).withdraw(amount);
    }
}
