// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.27;

import {IAllowanceTransfer} from "../lib/permit2/src/interfaces/IAllowanceTransfer.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {Math} from "../lib/morpho-utils/src/math/Math.sol";
import {Permit2Lib} from "../lib/permit2/src/libraries/Permit2Lib.sol";
import {SafeCast160} from "../lib/permit2/src/libraries/SafeCast160.sol";
import {ERC20} from "../lib/solmate/src/utils/SafeTransferLib.sol";

import {BaseBundler} from "./BaseBundler.sol";
import {BundlerLib} from "./libraries/BundlerLib.sol";

/// @title Permit2Bundler
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Bundler contract managing interactions with Uniswap's Permit2.
abstract contract Permit2Bundler is BaseBundler {
    using SafeCast160 for uint256;

    /* ACTIONS */

    /// @notice Approves the given `permitSingle.details.amount` of `permitSingle.details.token` from the initiator to
    /// be spent by `permitSingle.spender` via
    /// Permit2 with the given `permitSingle.sigDeadline` & EIP-712 `signature`.
    /// @param permitSingle The `PermitSingle` struct.
    /// @param signature The signature, serialized.
    /// @param skipRevert Whether to avoid reverting the call in case the signature is frontrunned.
    function approve2(IAllowanceTransfer.PermitSingle calldata permitSingle, bytes calldata signature, bool skipRevert)
        external
        hubOnly
    {
        try Permit2Lib.PERMIT2.permit(initiator(), permitSingle, signature) {}
        catch (bytes memory returnData) {
            if (!skipRevert) BundlerLib.lowLevelRevert(returnData);
        }
    }

    /// @notice Transfers the given `amount` of `token` from the initiator to the bundler via Permit2.
    /// @param token The address of the ERC20 token to transfer.
    /// @param receiver The address that will receive the tokens.
    /// @param amount The amount of `token` to transfer from the initiator. Capped at the initiator's balance.
    function transferFrom2(address token, address receiver, uint256 amount) external hubOnly {
        address _initiator = initiator();
        amount = Math.min(amount, ERC20(token).balanceOf(_initiator));

        require(amount != 0, ErrorsLib.ZeroAmount());

        Permit2Lib.PERMIT2.transferFrom(_initiator, receiver, amount.toUint160(), token);
    }
}
