// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IAaveV3Optimizer} from "../../interfaces/IAaveV3Optimizer.sol";
import {CoreAdapter, ErrorsLib, IERC20, SafeERC20} from "../CoreAdapter.sol";

/// @custom:security-contact security@morpho.org
/// @notice Contract allowing to migrate a position from AaveV3 Optimizer to Morpho easily.
contract AaveV3OptimizerMigrationAdapter is CoreAdapter {
    /* IMMUTABLES */

    /// @dev The AaveV3 optimizer contract address.
    IAaveV3Optimizer public immutable AAVE_V3_OPTIMIZER;

    /* CONSTRUCTOR */

    /// @param bundler3 The Bundler3 contract address
    /// @param aaveV3Optimizer The AaveV3 optimizer contract address.
    constructor(address bundler3, address aaveV3Optimizer) CoreAdapter(bundler3) {
        require(aaveV3Optimizer != address(0), ErrorsLib.ZeroAddress());

        AAVE_V3_OPTIMIZER = IAaveV3Optimizer(aaveV3Optimizer);
    }

    /* ACTIONS */

    /// @notice Repays on the AaveV3 Optimizer.
    /// @dev Underlying tokens must have been previously sent to the adapter.
    /// @param underlying The address of the underlying asset to repay.
    /// @param amount The amount of `underlying` to repay. Unlike with `morphoRepay`, the amount is capped at
    /// `onBehalf`s debt. Pass `type(uint).max` to repay the repay the maximum repayable debt (minimum of the adapter's
    /// balance and `onBehalf`'s debt).
    /// @param onBehalf The account on behalf of which the debt is repaid.
    function aaveV3OptimizerRepay(address underlying, uint256 amount, address onBehalf) external onlyBundler3 {
        // Amount will be capped at `onBehalf`'s debt by the optimizer.
        if (amount == type(uint256).max) amount = IERC20(underlying).balanceOf(address(this));

        require(amount != 0, ErrorsLib.ZeroAmount());

        SafeERC20.forceApprove(IERC20(underlying), address(AAVE_V3_OPTIMIZER), type(uint256).max);

        AAVE_V3_OPTIMIZER.repay(underlying, amount, onBehalf);

        SafeERC20.forceApprove(IERC20(underlying), address(AAVE_V3_OPTIMIZER), 0);
    }

    /// @notice Withdraws on the AaveV3 Optimizer.
    /// @dev Initiator must have previously approved the adapter to manage their AaveV3 Optimizer position.
    /// @param underlying The address of the underlying asset to withdraw.
    /// @param amount The amount of `underlying` to withdraw. Unlike with `morphoWithdraw`, the amount is capped at the
    /// initiator's max withdrawble amount. Pass `type(uint).max` to withdraw all.
    /// @param maxIterations The maximum number of iterations allowed during the matching process. If it is less than
    /// `_defaultIterations.withdraw`, the latter will be used. Pass 0 to fallback to the `_defaultIterations.withdraw`.
    /// @param receiver The account that will receive the withdrawn assets.
    function aaveV3OptimizerWithdraw(address underlying, uint256 amount, uint256 maxIterations, address receiver)
        external
        onlyBundler3
    {
        require(amount != 0, ErrorsLib.ZeroAmount());

        AAVE_V3_OPTIMIZER.withdraw(underlying, amount, initiator(), receiver, maxIterations);
    }

    /// @notice Withdraws on the AaveV3 Optimizer.
    /// @dev Initiator must have previously approved the adapter to manage their AaveV3 Optimizer position.
    /// @param underlying The address of the underlying asset to withdraw.
    /// @param amount The amount of `underlying` to withdraw. Unlike with `morphoWithdrawCollateral`, the amount is
    /// capped at the initiator's max withdrawable amount. Pass
    /// `type(uint).max` to always withdraw all.
    /// @param receiver The account that will receive the withdrawn assets.
    function aaveV3OptimizerWithdrawCollateral(address underlying, uint256 amount, address receiver)
        external
        onlyBundler3
    {
        require(amount != 0, ErrorsLib.ZeroAmount());

        AAVE_V3_OPTIMIZER.withdrawCollateral(underlying, amount, initiator(), receiver);
    }
}
