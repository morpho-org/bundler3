// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {SafeTransferLib, ERC20} from "../lib/solmate/src/utils/SafeTransferLib.sol";
import {IHub} from "./interfaces/IHub.sol";
import {Math} from "../lib/morpho-utils/src/math/Math.sol";

/// @title BaseBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Common contract to all Morpho Bundlers.
abstract contract BaseBundler {
    using SafeTransferLib for ERC20;

    address public immutable HUB;

    constructor(address hub) {
        require(hub != address(0), ErrorsLib.ZERO_ADDRESS);
        HUB = hub;
    }

    /* MODIFIERS */

    /// @dev Prevents a function from being called outside of a bundle context.
    /// @dev Ensures the value of initiator() is correct.
    modifier hubOnly() {
        require(msg.sender == HUB, ErrorsLib.UNAUTHORIZED_SENDER);
        _;
    }

    /* ACTIONS */

    /// @notice Transfers the minimum between the given `amount` and the bundler's balance of native asset from the
    /// bundler to `receiver`.
    /// @dev If the minimum happens to be zero, the transfer is silently skipped.
    /// @dev The receiver must not be the bundler or the zero address.
    /// @param receiver The address that will receive the native tokens.
    /// @param amount The amount of native tokens to transfer. Capped at the bundler's balance.
    function nativeTransfer(address receiver, uint256 amount) external payable hubOnly {
        require(receiver != address(0), ErrorsLib.ZERO_ADDRESS);
        require(receiver != address(this), ErrorsLib.BUNDLER_ADDRESS);

        amount = Math.min(amount, address(this).balance);

        _nativeTransfer(receiver, amount);
    }

    /// @notice Transfers the minimum between the given `amount` and the bundler's balance of `asset` from the bundler
    /// to `receiver`.
    /// @dev If the minimum happens to be zero the transfer is silently skipped.
    /// @dev The receiver must not be the bundler or the zero address.
    /// @param asset The address of the ERC20 token to transfer.
    /// @param receiver The address that will receive the tokens.
    /// @param amount The amount of `asset` to transfer. Capped at the bundler's balance.
    function erc20Transfer(address asset, address receiver, uint256 amount) external hubOnly {
        require(receiver != address(0), ErrorsLib.ZERO_ADDRESS);
        require(receiver != address(this), ErrorsLib.BUNDLER_ADDRESS);

        amount = Math.min(amount, ERC20(asset).balanceOf(address(this)));

        _erc20Transfer(asset, receiver, amount);
    }

    /* INTERNAL */

    /// @notice Returns the current initiator stored in the bundler.
    function initiator() internal view returns (address) {
        return IHub(HUB).initiator();
    }

    /// @dev Gives the max approval to `spender` to spend the given `asset` if not already approved.
    /// @dev Assumes that `type(uint256).max` is large enough to never have to increase the allowance again.
    function _approveMaxTo(address asset, address spender) internal {
        if (ERC20(asset).allowance(address(this), spender) == 0) {
            ERC20(asset).safeApprove(spender, type(uint256).max);
        }
    }

    /// @dev Bubbles up the revert reason / custom error encoded in `returnData`.
    /// @dev Assumes `returnData` is the return data of any kind of failing CALL to a contract.
    function _revert(bytes memory returnData) internal pure {
        uint256 length = returnData.length;
        require(length > 0, ErrorsLib.CALL_FAILED);

        assembly ("memory-safe") {
            revert(add(32, returnData), length)
        }
    }

    /// @notice Transfer an `amount` of `asset` to `receiver`.
    /// @dev Skips if receiver is address(this) or the amount is 0.
    /// @param asset The address of the ERC20 token to transfer.
    /// @param receiver The address that will receive the tokens.
    /// @param amount The amount of `asset` to transfer.
    function _erc20Transfer(address asset, address receiver, uint256 amount) internal {
        if (receiver != address(this) && amount > 0) {
            ERC20(asset).safeTransfer(receiver, amount);
        }
    }

    /// @notice Transfer an `amount` of native tokens to `receiver`.
    /// @dev Skips if receiver is address(this) or the amount is 0.
    /// @param receiver The address that will receive the tokens.
    /// @param amount The amount of `asset` to transfer.
    function _nativeTransfer(address receiver, uint256 amount) internal {
        if (receiver != address(this) && amount > 0) {
            SafeTransferLib.safeTransferETH(receiver, amount);
        }
    }
}
