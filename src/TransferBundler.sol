// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.27;

import {Math} from "../lib/morpho-utils/src/math/Math.sol";
import "./libraries/ErrorsLib.sol" as ErrorsLib;
import {SafeTransferLib, ERC20} from "../lib/solmate/src/utils/SafeTransferLib.sol";

import {BaseBundler} from "./BaseBundler.sol";
import {BundlerLib} from "./libraries/BundlerLib.sol";

/// @title TransferBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Enables transfer of ERC20 tokens from the initiator to arbitrary addresses.
abstract contract TransferBundler is BaseBundler {
    using SafeTransferLib for ERC20;

    /* ACTIONS */

    /// @notice Transfers the given `amount` of `token` from sender to this contract via ERC20 transferFrom.
    /// @notice User must have given sufficient allowance to the Bundler to spend their tokens.
    /// @notice The amount must be strictly positive.
    /// @param token The address of the ERC20 token to transfer.
    /// @param receiver The address that will receive the tokens.
    /// @param amount The amount of `token` to transfer from the initiator. Capped at the initiator's balance.
    function erc20TransferFrom(address token, address receiver, uint256 amount) external hubOnly {
        address _initiator = initiator();
        amount = Math.min(amount, ERC20(token).balanceOf(_initiator));

        require(amount != 0, ErrorsLib.ZeroAmount());

        ERC20(token).safeTransferFrom(_initiator, receiver, amount);
    }

    function erc20ApproveMaxTo(address asset, address spender) external hubOnly {
        require(asset != address(0), ErrorsLib.ZERO_ADDRESS);
        require(spender != address(0), ErrorsLib.ZERO_ADDRESS);
        BundlerLib.approveMaxTo(asset, spender);
    }
}
