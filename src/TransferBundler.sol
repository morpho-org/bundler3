// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.27;

import {BaseBundler} from "./BaseBundler.sol";
import {Math} from "../lib/morpho-utils/src/math/Math.sol";
import {SafeTransferLib, ERC20} from "../lib/solmate/src/utils/SafeTransferLib.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";

/// @title TransferBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Bundler contract that does transfers from the initiator.
abstract contract TransferBundler is BaseBundler {
    using SafeTransferLib for ERC20;

    /* ACTIONS */

    /// @notice Transfers the given `amount` of `asset` from sender to this contract via ERC20 transferFrom.
    /// @notice User must have given sufficient allowance to the Bundler to spend their tokens.
    /// @notice The amount must be strictly positive.
    /// @param asset The address of the ERC20 token to transfer.
    /// @param receiver The address that will receive the assets.
    /// @param amount The amount of `asset` to transfer from the initiator. Capped at the initiator's balance.
    function erc20TransferFrom(address asset, address receiver, uint256 amount) external hubOnly {
        address _initiator = initiator();
        amount = Math.min(amount, ERC20(asset).balanceOf(_initiator));

        require(amount != 0, ErrorsLib.ZERO_AMOUNT);

        ERC20(asset).safeTransferFrom(_initiator, receiver, amount);
    }
}
