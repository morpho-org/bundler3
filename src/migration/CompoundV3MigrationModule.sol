// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {ICompoundV3} from "../interfaces/ICompoundV3.sol";

import {Math} from "../../lib/morpho-utils/src/math/Math.sol";
import {ErrorsLib} from "../libraries/ErrorsLib.sol";

import {BaseModule} from "../BaseModule.sol";
import {ERC20} from "../../lib/solmate/src/utils/SafeTransferLib.sol";
import {ModuleLib} from "../libraries/ModuleLib.sol";

/// @title CompoundV3MigrationModule
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Contract allowing to migrate a position from Compound V3 to Morpho Blue easily.
contract CompoundV3MigrationModule is BaseModule {
    /* CONSTRUCTOR */

    /// @param bundler The Bundler contract address.
    constructor(address bundler) BaseModule(bundler) {}

    /* ACTIONS */

    /// @notice Repays on a CompoundV3 instance.
    /// @dev Underlying tokens must have been previously sent to the module.
    /// @dev Assumes the given `instance` is a CompoundV3 instance.
    /// @param instance The address of the CompoundV3 instance to call.
    /// @param amount The amount of base token to repay. Unlike with `morphoRepay`, the amount is capped at `onBehalf`'s
    /// debt. Pass `type(uint).max` to repay the maximum repayable debt (minimum of the module's balance and
    /// `onBehalf`'s debt).
    /// @param onBehalf The account on behalf of which the debt is repaid.
    function compoundV3Repay(address instance, uint256 amount, address onBehalf) external onlyBundler {
        address asset = ICompoundV3(instance).baseToken();

        if (amount == type(uint256).max) {
            amount = ERC20(asset).balanceOf(address(this));
        }
        amount = Math.min(amount, ICompoundV3(instance).borrowBalanceOf(onBehalf));

        require(amount != 0, ErrorsLib.ZeroAmount());

        ModuleLib.approveMaxToIfAllowanceZero(asset, instance);

        // Compound V3 uses signed accounting: supplying to a negative balance actually repays the borrow position.
        ICompoundV3(instance).supplyTo(onBehalf, asset, amount);
    }

    /// @notice Withdraws from a CompoundV3 instance.
    /// @dev Initiator must have previously approved the module to manage their CompoundV3 position.
    /// @dev Assumes the given `instance` is a CompoundV3 instance.
    /// @param instance The address of the CompoundV3 instance to call.
    /// @param asset The address of the token to withdraw.
    /// @param amount The amount of `asset` to withdraw. Unlike with `morphoWithdraw`, the amount is capped at the
    /// initiator's max withdrawable amount. Pass `type(uint).max` to always withdraw the initiator's balance.
    /// @param receiver The account receiving the withdrawn assets.
    function compoundV3WithdrawFrom(address instance, address asset, uint256 amount, address receiver)
        external
        onlyBundler
    {
        address _initiator = initiator();
        uint256 balance = asset == ICompoundV3(instance).baseToken()
            ? ICompoundV3(instance).balanceOf(_initiator)
            : ICompoundV3(instance).userCollateral(_initiator, asset).balance;

        amount = Math.min(amount, balance);

        require(amount != 0, ErrorsLib.ZeroAmount());

        ICompoundV3(instance).withdrawFrom(_initiator, receiver, asset, amount);
    }

    /// @notice Approves on a CompoundV3 instance.
    /// @dev Assumes the given instance is a CompoundV3 instance.
    /// @param instance The address of the CompoundV3 instance to call.
    /// @param isAllowed Whether the module is allowed to manage the initiator's position or not.
    /// @param nonce The nonce of the signed message.
    /// @param expiry The expiry of the signed message.
    /// @param v The `v` component of a signature.
    /// @param r The `r` component of a signature.
    /// @param s The `s` component of a signature.
    /// @param skipRevert Whether to avoid reverting the call in case the signature is frontrunned.
    function compoundV3AllowBySig(
        address instance,
        bool isAllowed,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s,
        bool skipRevert
    ) external onlyBundler {
        try ICompoundV3(instance).allowBySig(initiator(), address(this), isAllowed, nonce, expiry, v, r, s) {}
        catch (bytes memory returnData) {
            if (!skipRevert) ModuleLib.lowLevelRevert(returnData);
        }
    }
}
