// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {IAaveV3Optimizer, Signature} from "./interfaces/IAaveV3Optimizer.sol";

import {Math} from "../../lib/morpho-utils/src/math/Math.sol";
import {ErrorsLib} from "../libraries/ErrorsLib.sol";

import {BaseModule} from "../BaseModule.sol";
import {ERC20} from "../../lib/solmate/src/utils/SafeTransferLib.sol";
import {ModuleLib} from "../libraries/ModuleLib.sol";

/// @title AaveV3OptimizerMigrationModuleV2
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Contract allowing to migrate a position from AaveV3 Optimizer to Morpho Blue easily.
contract AaveV3OptimizerMigrationModuleV2 is BaseModule {
    /* IMMUTABLES */

    /// @dev The AaveV3 optimizer contract address.
    IAaveV3Optimizer public immutable AAVE_V3_OPTIMIZER;

    /* CONSTRUCTOR */

    /// @param bundler The Bundler contract address
    /// @param aaveV3Optimizer The AaveV3 optimizer contract address. Assumes it is non-zero (not expected to be an
    /// input at deployment).
    constructor(address bundler, address aaveV3Optimizer) BaseModule(bundler) {
        require(aaveV3Optimizer != address(0), ErrorsLib.ZeroAddress());

        AAVE_V3_OPTIMIZER = IAaveV3Optimizer(aaveV3Optimizer);
    }

    /* ACTIONS */

    /// @notice Repays `amount` of `underlying` on the AaveV3 Optimizer, on behalf of the initiator.
    /// @dev Underlying tokens must have been previously sent to the module.
    /// @param underlying The address of the underlying asset to repay.
    /// @param amount The amount of `underlying` to repay. Capped at the maximum repayable debt
    /// (mininimum of the module's balance and the initiator's debt).
    function aaveV3OptimizerRepay(address underlying, uint256 amount) external bundlerOnly {
        amount = Math.min(amount, ERC20(underlying).balanceOf(address(this)));

        require(amount != 0, ErrorsLib.ZeroAmount());

        ModuleLib.approveMaxToIfAllowanceZero(underlying, address(AAVE_V3_OPTIMIZER));

        AAVE_V3_OPTIMIZER.repay(underlying, amount, initiator());
    }

    /// @notice Withdraws `amount` of `underlying` on the AaveV3 Optimizer, on behalf of the initiator`.
    /// @dev Initiator must have previously approved the module to manage their AaveV3 Optimizer position.
    /// @param underlying The address of the underlying asset to withdraw.
    /// @param amount The amount of `underlying` to withdraw. Pass `type(uint256).max` to withdraw all.
    /// @param maxIterations The maximum number of iterations allowed during the matching process. If it is less than
    /// @param receiver The account that will receive the withdrawn assets.
    /// `_defaultIterations.withdraw`, the latter will be used. Pass 0 to fallback to the `_defaultIterations.withdraw`.
    function aaveV3OptimizerWithdraw(address underlying, uint256 amount, uint256 maxIterations, address receiver)
        external
        bundlerOnly
    {
        AAVE_V3_OPTIMIZER.withdraw(underlying, amount, initiator(), receiver, maxIterations);
    }

    /// @notice Withdraws `amount` of `underlying` used as collateral on the AaveV3 Optimizer, on behalf of the
    /// initiator.
    /// @dev Initiator must have previously approved the module to manage their AaveV3 Optimizer position.
    /// @param underlying The address of the underlying asset to withdraw.
    /// @param amount The amount of `underlying` to withdraw. Pass `type(uint256).max` to withdraw all.
    /// @param receiver The account that will receive the withdrawn assets.
    function aaveV3OptimizerWithdrawCollateral(address underlying, uint256 amount, address receiver)
        external
        bundlerOnly
    {
        AAVE_V3_OPTIMIZER.withdrawCollateral(underlying, amount, initiator(), receiver);
    }

    /// @notice Approves the module to act on behalf of the initiator on the AaveV3 Optimizer, given a signed EIP-712
    /// approval message.
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
    ) external bundlerOnly {
        try AAVE_V3_OPTIMIZER.approveManagerWithSig(initiator(), address(this), isApproved, nonce, deadline, signature)
        {} catch (bytes memory returnData) {
            if (!skipRevert) ModuleLib.lowLevelRevert(returnData);
        }
    }
}
