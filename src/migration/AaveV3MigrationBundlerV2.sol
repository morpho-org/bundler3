// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.26;

import {IAaveV3} from "./interfaces/IAaveV3.sol";

import {Math} from "../../lib/morpho-utils/src/math/Math.sol";
import {ErrorsLib} from "../libraries/ErrorsLib.sol";

import {MigrationBundler, ERC20} from "./MigrationBundler.sol";

/// @title AaveV3MigrationBundlerV2
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Contract allowing to migrate a position from Aave V3 to Morpho Blue easily.
contract AaveV3MigrationBundlerV2 is MigrationBundler {
    /* IMMUTABLES */

    /// @dev The AaveV3 contract address.
    IAaveV3 public immutable AAVE_V3_POOL;

    /* CONSTRUCTOR */

    /// @param morpho The Morpho contract Address.
    /// @param aaveV3Pool The AaveV3 contract address. Assumes it is non-zero (not expected to be an input at
    /// deployment).
    constructor(address morpho, address aaveV3Pool) MigrationBundler(morpho) {
        require(aaveV3Pool != address(0), ErrorsLib.ZERO_ADDRESS);

        AAVE_V3_POOL = IAaveV3(aaveV3Pool);
    }

    /* ACTIONS */

    /// @notice Repays `amount` of `asset` on AaveV3, on behalf of the initiator.
    /// @dev Initiator must have previously transferred their assets to the bundler.
    /// @param asset The address of the token to repay.
    /// @param amount The amount of `asset` to repay. Capped at the maximum repayable debt
    /// (mininimum of the bundler's balance and the initiator's debt).
    /// @param interestRateMode The interest rate mode of the position.
    function aaveV3Repay(address asset, uint256 amount, uint256 interestRateMode) external payable protected {
        amount = Math.min(amount, ERC20(asset).balanceOf(address(this)));

        require(amount != 0, ErrorsLib.ZERO_AMOUNT);

        _approveMaxTo(asset, address(AAVE_V3_POOL));

        AAVE_V3_POOL.repay(asset, amount, interestRateMode, initiator());
    }

    /// @notice Withdraws `amount` of `asset` on AaveV3, on behalf of the initiator.
    /// @notice Withdrawn assets are received by the bundler and should be used afterwards.
    /// @dev Initiator must have previously transferred their aTokens to the bundler.
    /// @param asset The address of the token to withdraw.
    /// @param amount The amount of `asset` to withdraw. Pass `type(uint256).max` to withdraw all.
    function aaveV3Withdraw(address asset, uint256 amount) external payable protected {
        AAVE_V3_POOL.withdraw(asset, amount, address(this));
    }
}
