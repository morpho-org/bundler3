// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./libraries/ErrorsLib.sol" as ErrorsLib;
import {ERC20} from "../lib/solmate/src/utils/SafeTransferLib.sol";
import {IHub} from "./interfaces/IHub.sol";
import {Math} from "../lib/morpho-utils/src/math/Math.sol";
import {BundlerLib} from "./libraries/BundlerLib.sol";

/// @title BaseBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Common contract to all Morpho Bundlers.
contract BaseBundler {
    address public immutable HUB;

    constructor(address hub) {
        require(hub != address(0), ErrorsLib.ZeroAddress());
        HUB = hub;
    }

    /* MODIFIERS */

    /// @dev Prevents a function from being called outside of a bundle context.
    /// @dev Ensures the value of initiator() is correct.
    modifier hubOnly() {
        require(msg.sender == HUB, ErrorsLib.UnauthorizedSender());
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
        require(receiver != address(0), ErrorsLib.ZeroAddress());
        require(receiver != address(this), ErrorsLib.BundlerAddress());

        amount = Math.min(amount, address(this).balance);

        BundlerLib.nativeTransfer(receiver, amount);
    }

    /// @notice Transfers the minimum between the given `amount` and the bundler's balance of `token` from the bundler
    /// to `receiver`.
    /// @dev If the minimum happens to be zero the transfer is silently skipped.
    /// @dev The receiver must not be the bundler or the zero address.
    /// @param token The address of the ERC20 token to transfer.
    /// @param receiver The address that will receive the tokens.
    /// @param amount The amount of `token` to transfer. Capped at the bundler's balance.
    function erc20Transfer(address token, address receiver, uint256 amount) external hubOnly {
        require(receiver != address(0), ErrorsLib.ZeroAddress());
        require(receiver != address(this), ErrorsLib.BundlerAddress());

        amount = Math.min(amount, ERC20(token).balanceOf(address(this)));

        BundlerLib.erc20Transfer(token, receiver, amount);
    }

    /* INTERNAL */

    /// @notice Returns the current initiator stored in the bundler.
    /// @dev If the caller is not the hub, the initiator value may be 0.
    function initiator() internal view returns (address) {
        return IHub(HUB).initiator();
    }
}
