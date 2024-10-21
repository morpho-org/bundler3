// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {SafeTransferLib, ERC20} from "../lib/solmate/src/utils/SafeTransferLib.sol";
import {IHub} from "./interfaces/IHub.sol";
import {Math} from "../lib/morpho-utils/src/math/Math.sol";

/// @title BaseBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Morpho Bundler Bundler abstract contract.
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

    /* EXTERNAL */

    /// @notice Transfers the minimum between the given `amount` and the bundler's balance of native asset from the
    /// bundler to `recipient`.
    /// @dev If the minimum happens to be zero, the transfer is silently skipped.
    /// @param recipient The address that will receive the native tokens.
    /// @param amount The amount of native tokens to transfer. Capped at the bundler's balance.
    function nativeTransfer(address recipient, uint256 amount) external payable hubOnly {
        require(recipient != address(0), ErrorsLib.ZERO_ADDRESS);
        require(recipient != address(this), ErrorsLib.BUNDLER_ADDRESS);

        amount = Math.min(amount, address(this).balance);

        if (amount == 0) return;

        SafeTransferLib.safeTransferETH(recipient, amount);
    }

    /// @notice Transfers the minimum between the given `amount` and the bundler's balance of `asset` from the bundler
    /// to `recipient`.
    /// @dev If the minimum happens to be zero, the transfer is silently skipped.
    /// @param asset The address of the ERC20 token to transfer.
    /// @param recipient The address that will receive the tokens.
    /// @param amount The amount of `asset` to transfer. Capped at the bundler's balance.
    function erc20Transfer(address asset, address recipient, uint256 amount) external hubOnly {
        require(recipient != address(0), ErrorsLib.ZERO_ADDRESS);
        require(recipient != address(this), ErrorsLib.BUNDLER_ADDRESS);

        amount = Math.min(amount, ERC20(asset).balanceOf(address(this)));

        if (amount == 0) return;

        ERC20(asset).safeTransfer(recipient, amount);
    }

    /// @notice Transfers the given `amount` of `asset` from sender to this contract via ERC20 transferFrom.
    /// @notice User must have given sufficient allowance to the Bundler to spend their tokens.
    /// @dev All bundlers get this function by default to ease inter-bundler interactions.
    /// @param asset The address of the ERC20 token to transfer.
    /// @param amount The amount of `asset` to transfer from the initiator. Capped at the initiator's balance.
    /// @param receiver The address that will receive the assets.
    function erc20TransferFrom(address asset, uint256 amount, address receiver) external virtual hubOnly {
        address _initiator = initiator();
        amount = Math.min(amount, ERC20(asset).balanceOf(_initiator));

        require(amount != 0, ErrorsLib.ZERO_AMOUNT);

        ERC20(asset).safeTransferFrom(_initiator, receiver, amount);
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
}
