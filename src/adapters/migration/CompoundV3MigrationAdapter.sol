// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {ICompoundV3} from "../../interfaces/ICompoundV3.sol";

import {Math} from "../../../lib/morpho-utils/src/math/Math.sol";
import {CoreAdapter, ErrorsLib, IERC20, UtilsLib} from "../CoreAdapter.sol";

/// @custom:contact security@morpho.org
/// @notice Contract allowing to migrate a position from Compound V3 to Morpho Blue easily.
contract CompoundV3MigrationAdapter is CoreAdapter {
    /* CONSTRUCTOR */

    /// @param bundler The Bundler contract address.
    constructor(address bundler) CoreAdapter(bundler) {}

    /* ACTIONS */

    /// @notice Repays on a CompoundV3 instance.
    /// @dev Underlying tokens must have been previously sent to the adapter.
    /// @dev Assumes the given `instance` is a CompoundV3 instance.
    /// @param instance The address of the CompoundV3 instance to call.
    /// @param amount The amount of base token to repay. Unlike with `morphoRepay`, the amount is capped at `onBehalf`'s
    /// debt. Pass `type(uint).max` to repay the maximum repayable debt (minimum of the adapter's balance and
    /// `onBehalf`'s debt).
    /// @param onBehalf The account on behalf of which the debt is repaid.
    function compoundV3Repay(address instance, uint256 amount, address onBehalf) external onlyBundler {
        address asset = ICompoundV3(instance).baseToken();

        if (amount == type(uint256).max) amount = IERC20(asset).balanceOf(address(this));

        amount = Math.min(amount, ICompoundV3(instance).borrowBalanceOf(onBehalf));

        require(amount != 0, ErrorsLib.ZeroAmount());

        UtilsLib.forceApproveMaxTo(asset, instance);

        // Compound V3 uses signed accounting: supplying to a negative balance actually repays the borrow position.
        ICompoundV3(instance).supplyTo(onBehalf, asset, amount);
    }

    /// @notice Withdraws from a CompoundV3 instance.
    /// @dev Initiator must have previously approved the adapter to manage their CompoundV3 position.
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
        address _initiator = _initiator();
        uint256 balance = asset == ICompoundV3(instance).baseToken()
            ? ICompoundV3(instance).balanceOf(_initiator)
            : ICompoundV3(instance).userCollateral(_initiator, asset).balance;

        amount = Math.min(amount, balance);

        require(amount != 0, ErrorsLib.ZeroAmount());

        ICompoundV3(instance).withdrawFrom(_initiator, receiver, asset, amount);
    }
}
