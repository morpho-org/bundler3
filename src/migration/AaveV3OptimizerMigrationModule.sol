// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IAaveV3Optimizer, Signature} from "../interfaces/IAaveV3Optimizer.sol";

import {ErrorsLib} from "../libraries/ErrorsLib.sol";

import {BaseModule} from "../BaseModule.sol";
import {ERC20} from "../../lib/solmate/src/utils/SafeTransferLib.sol";
import {ModuleLib} from "../libraries/ModuleLib.sol";

/// @title AaveV3OptimizerMigrationModule
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Contract allowing to migrate a position from AaveV3 Optimizer to Morpho Blue easily.
contract AaveV3OptimizerMigrationModule is BaseModule {
    /* IMMUTABLES */

    /// @dev The AaveV3 optimizer contract address.
    IAaveV3Optimizer public immutable AAVE_V3_OPTIMIZER;

    /* CONSTRUCTOR */

    /// @param bundler The Bundler contract address
    /// @param aaveV3Optimizer The AaveV3 optimizer contract address.
    constructor(address bundler, address aaveV3Optimizer) BaseModule(bundler) {
        require(aaveV3Optimizer != address(0), ErrorsLib.ZeroAddress());

        AAVE_V3_OPTIMIZER = IAaveV3Optimizer(aaveV3Optimizer);
    }

    /* ACTIONS */

    /// @notice Repays on the AaveV3 Optimizer.
    /// @dev Underlying tokens must have been previously sent to the module.
    /// @param underlying The address of the underlying asset to repay.
    /// @param amount The amount of `underlying` to repay. Unlike with `morphoRepay`, the amount is capped at
    /// `onBehalf`s debt. Pass `type(uint).max` to repay the repay the maximum repayable debt (minimum of the module's
    /// balance and `onBehalf`'s debt).
    /// @param onBehalf The account on behalf of which the debt is repaid.
    function aaveV3OptimizerRepay(address underlying, uint256 amount, address onBehalf) external onlyBundler {
        // Amount will be capped at `onBehalf`'s debt by the optimizer.
        if (amount == type(uint256).max) amount = ERC20(underlying).balanceOf(address(this));

        require(amount != 0, ErrorsLib.ZeroAmount());

        ModuleLib.approveMaxToIfAllowanceZero(underlying, address(AAVE_V3_OPTIMIZER));

        AAVE_V3_OPTIMIZER.repay(underlying, amount, onBehalf);
    }

    /// @notice Withdraws on the AaveV3 Optimizer.
    /// @dev Initiator must have previously approved the module to manage their AaveV3 Optimizer position.
    /// @param underlying The address of the underlying asset to withdraw.
    /// @param amount The amount of `underlying` to withdraw. Unlike with `morphoWithdraw`, the amount is capped at the
    /// initiator's max withdrawble amount. Pass `type(uint).max` to withdraw all.
    /// @param maxIterations The maximum number of iterations allowed during the matching process. If it is less than
    /// `_defaultIterations.withdraw`, the latter will be used. Pass 0 to fallback to the `_defaultIterations.withdraw`.
    /// @param receiver The account that will receive the withdrawn assets.
    function aaveV3OptimizerWithdraw(address underlying, uint256 amount, uint256 maxIterations, address receiver)
        external
        onlyBundler
    {
        require(amount != 0, ErrorsLib.ZeroAmount());
        AAVE_V3_OPTIMIZER.withdraw(underlying, amount, _initiator(), receiver, maxIterations);
    }

    /// @notice Withdraws on the AaveV3 Optimizer.
    /// @dev Initiator must have previously approved the module to manage their AaveV3 Optimizer position.
    /// @param underlying The address of the underlying asset to withdraw.
    /// @param amount The amount of `underlying` to withdraw. Unlike with `morphoWithdrawCollateral`, the amount is
    /// capped at the initiator's max withdrawable amount. Pass
    /// `type(uint).max` to always withdraw all.
    /// @param receiver The account that will receive the withdrawn assets.
    function aaveV3OptimizerWithdrawCollateral(address underlying, uint256 amount, address receiver)
        external
        onlyBundler
    {
        require(amount != 0, ErrorsLib.ZeroAmount());
        AAVE_V3_OPTIMIZER.withdrawCollateral(underlying, amount, _initiator(), receiver);
    }

    /// @notice Approves on the AaveV3 Optimizer.
    /// @param isApproved Whether the module is allowed to manage the initiator's position or not.
    /// @param nonce The nonce of the signed message.
    /// @param deadline The deadline of the signed message.
    /// @param signature The signature of the message.
    /// @param skipRevert Whether to avoid reverting the call in case the signature is frontrunned.
    function aaveV3OptimizerApproveManagerWithSig(
        bool isApproved,
        uint256 nonce,
        uint256 deadline,
        Signature calldata signature,
        bool skipRevert
    ) external onlyBundler {
        try AAVE_V3_OPTIMIZER.approveManagerWithSig(_initiator(), address(this), isApproved, nonce, deadline, signature)
        {} catch (bytes memory returnData) {
            if (!skipRevert) ModuleLib.lowLevelRevert(returnData);
        }
    }
}
