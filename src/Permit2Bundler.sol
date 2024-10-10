// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IAllowanceTransfer} from "../lib/permit2/src/interfaces/IAllowanceTransfer.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {Math} from "../lib/morpho-utils/src/math/Math.sol";
import {Permit2Lib} from "../lib/permit2/src/libraries/Permit2Lib.sol";
import {SafeCast160} from "../lib/permit2/src/libraries/SafeCast160.sol";
import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";

import {BaseBundler} from "./BaseBundler.sol";

/// @title Permit2Bundler
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
/// @notice Bundler contract managing interactions with Uniswap's Permit2.
abstract contract Permit2Bundler is BaseBundler {
    using SafeCast160 for uint256;

    /* ACTIONS */

    /// @notice Approves the given `amount` of `asset` from the initiator to be spent by `permitSingle.spender` via
    /// Permit2 with the given `deadline` & EIP-712 `signature`.
    /// @param permitSingle The `PermitSingle` struct.
    /// @param signature The signature, serialized.
    /// @param skipRevert Whether to avoid reverting the call in case the signature is frontrunned.
    function approve2(IAllowanceTransfer.PermitSingle calldata permitSingle, bytes calldata signature, bool skipRevert)
        external
        payable
        protected
    {
        try Permit2Lib.PERMIT2.permit(initiator, permitSingle, signature) {}
        catch (bytes memory returnData) {
            if (!skipRevert) _revert(returnData);
        }
    }

    /// @notice Transfers the given `amount` of `asset` from the initiator to the bundler via Permit2.
    /// @param asset The address of the ERC20 token to transfer.
    /// @param amount The amount of `asset` to transfer from the initiator. Capped at the initiator's balance.
    function transferFrom2(address asset, uint256 amount) external payable protected {
        address _initiator = initiator;
        amount = Math.min(amount, ERC20(asset).balanceOf(_initiator));

        require(amount != 0, ErrorsLib.ZERO_AMOUNT);

        Permit2Lib.PERMIT2.transferFrom(_initiator, address(this), amount.toUint160(), asset);
    }
}
