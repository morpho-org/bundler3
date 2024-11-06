// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./ErrorsLib.sol" as ErrorsLib;
import {SafeTransferLib, ERC20} from "../../lib/solmate/src/utils/SafeTransferLib.sol";

/// @title BundlerLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing common bundler functionality
library BundlerLib {
    using SafeTransferLib for ERC20;

    /// @dev Gives the max approval to `spender` to spend the given `token` if not already approved.
    /// @dev Assumes that `type(uint256).max` is large enough to never have to increase the allowance again.
    function approveMaxTo(address token, address spender) internal {
        if (ERC20(token).allowance(address(this), spender) == 0) {
            ERC20(token).safeApprove(spender, type(uint256).max);
        }
    }

    /// @dev Bubbles up the revert reason / custom error encoded in `returnData`.
    /// @dev Assumes `returnData` is the return data of any kind of failing CALL to a contract.
    function lowLevelRevert(bytes memory returnData) internal pure {
        assembly ("memory-safe") {
            revert(add(32, returnData), mload(returnData))
        }
    }

    /// @notice Transfer an `amount` of `token` to `receiver`.
    /// @dev Skips if receiver is address(this) or the amount is 0.
    /// @param token The address of the ERC20 token to transfer.
    /// @param receiver The address that will receive the tokens.
    /// @param amount The amount of `token` to transfer.
    function erc20Transfer(address token, address receiver, uint256 amount) internal {
        if (receiver != address(this) && amount > 0) {
            ERC20(token).safeTransfer(receiver, amount);
        }
    }

    /// @notice Transfer an `amount` of native tokens to `receiver`.
    /// @dev Skips if receiver is address(this) or the amount is 0.
    /// @param receiver The address that will receive the tokens.
    /// @param amount The amount of native tokens to transfer.
    function nativeTransfer(address receiver, uint256 amount) internal {
        if (receiver != address(this) && amount > 0) {
            SafeTransferLib.safeTransferETH(receiver, amount);
        }
    }
}
