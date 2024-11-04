// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "./ErrorsLib.sol";
import {SafeTransferLib, ERC20} from "../../lib/solmate/src/utils/SafeTransferLib.sol";

/// @title BundlerLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing common bundler functionality
library BundlerLib {
    using SafeTransferLib for ERC20;

    /// @dev Gives the max approval to `spender` to spend the given `asset` if not already approved.
    /// @dev Assumes that `type(uint256).max` is large enough to never have to increase the allowance again.
    function approveMaxTo(address asset, address spender) internal {
        if (ERC20(asset).allowance(address(this), spender) == 0) {
            ERC20(asset).safeApprove(spender, type(uint256).max);
        }
    }

    /// @dev Bubbles up the revert reason / custom error encoded in `returnData`.
    /// @dev Assumes `returnData` is the return data of any kind of failing CALL to a contract.
    function lowLevelRevert(bytes memory returnData) internal pure {
        assembly ("memory-safe") {
            revert(add(32, returnData), mload(returnData))
        }
    }

    /// @notice Transfer an `amount` of `asset` to `receiver`.
    /// @dev Skips if receiver is address(this) or the amount is 0.
    /// @param asset The address of the ERC20 token to transfer.
    /// @param receiver The address that will receive the tokens.
    /// @param amount The amount of `asset` to transfer.
    function erc20Transfer(address asset, address receiver, uint256 amount) internal {
        if (receiver != address(this) && amount > 0) {
            ERC20(asset).safeTransfer(receiver, amount);
        }
    }

    /// @notice Transfer an `amount` of native tokens to `receiver`.
    /// @dev Skips if receiver is address(this) or the amount is 0.
    /// @param receiver The address that will receive the tokens.
    /// @param amount The amount of `asset` to transfer.
    function nativeTransfer(address receiver, uint256 amount) internal {
        if (receiver != address(this) && amount > 0) {
            SafeTransferLib.safeTransferETH(receiver, amount);
        }
    }
}
