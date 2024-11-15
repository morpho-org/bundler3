// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {IAaveV3} from "./interfaces/IAaveV3.sol";

import {Math} from "../../lib/morpho-utils/src/math/Math.sol";
import {ErrorsLib} from "../libraries/ErrorsLib.sol";

import {BaseModule} from "../BaseModule.sol";
import {ERC20} from "../../lib/solmate/src/utils/SafeTransferLib.sol";
import {ModuleLib} from "../libraries/ModuleLib.sol";

/// @title AaveV3MigrationModuleV2
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Contract allowing to migrate a position from Aave V3 to Morpho Blue easily.
contract AaveV3MigrationModuleV2 is BaseModule {
    /* IMMUTABLES */

    /// @dev The AaveV3 contract address.
    IAaveV3 public immutable AAVE_V3_POOL;

    /* CONSTRUCTOR */

    /// @param bundler The Bundler contract address
    /// @param aaveV3Pool The AaveV3 contract address. Assumes it is non-zero (not expected to be an input at
    /// deployment).
    constructor(address bundler, address aaveV3Pool) BaseModule(bundler) {
        require(aaveV3Pool != address(0), ErrorsLib.ZeroAddress());

        AAVE_V3_POOL = IAaveV3(aaveV3Pool);
    }

    /* ACTIONS */

    /// @notice Repays `amount` of `token` on AaveV3, on behalf of the initiator.
    /// @dev Underlying tokens must have been previously sent to the module.
    /// @param token The address of the token to repay.
    /// @param amount The amount of `token` to repay. Capped at the maximum repayable debt
    /// (mininimum of the module's balance and the initiator's debt).
    /// @param interestRateMode The interest rate mode of the position.
    function aaveV3Repay(address token, uint256 amount, uint256 interestRateMode) external bundlerOnly {
        amount = Math.min(amount, ERC20(token).balanceOf(address(this)));

        require(amount != 0, ErrorsLib.ZeroAmount());

        ModuleLib.approveMaxToIfAllowanceZero(token, address(AAVE_V3_POOL));

        AAVE_V3_POOL.repay(token, amount, interestRateMode, initiator());
    }

    /// @notice Withdraws `amount` of `token` on AaveV3, on behalf of the initiator.
    /// @dev aTokens must have been previously sent to the module.
    /// @param token The address of the token to withdraw.
    /// @param amount The amount of `token` to withdraw. Pass `type(uint256).max` to withdraw all.
    /// @param receiver The account receiving the withdrawn tokens.
    function aaveV3Withdraw(address token, uint256 amount, address receiver) external bundlerOnly {
        AAVE_V3_POOL.withdraw(token, amount, receiver);
    }
}
