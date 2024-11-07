// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {IAaveV3} from "./interfaces/IAaveV3.sol";

import {Math} from "../../lib/morpho-utils/src/math/Math.sol";
import {ErrorsLib} from "../libraries/ErrorsLib.sol";

import {BaseBundler} from "../BaseBundler.sol";
import {ERC20} from "./MigrationBundler.sol";
import {BundlerLib} from "../libraries/BundlerLib.sol";

/// @title AaveV3MigrationBundlerV2
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Contract allowing to migrate a position from Aave V3 to Morpho Blue easily.
contract AaveV3MigrationBundlerV2 is BaseBundler {
    /* IMMUTABLES */

    /// @dev The AaveV3 contract address.
    IAaveV3 public immutable AAVE_V3_POOL;

    /* CONSTRUCTOR */

    /// @param hub The Hub contract address
    /// @param aaveV3Pool The AaveV3 contract address. Assumes it is non-zero (not expected to be an input at
    /// deployment).
    constructor(address hub, address aaveV3Pool) BaseBundler(hub) {
        require(aaveV3Pool != address(0), ErrorsLib.ZeroAddress());

        AAVE_V3_POOL = IAaveV3(aaveV3Pool);
    }

    /* ACTIONS */

    /// @notice Repays `amount` of `token` on AaveV3, on behalf of the initiator.
    /// @dev Initiator must have previously transferred their tokens to the bundler.
    /// @param token The address of the token to repay.
    /// @param amount The amount of `token` to repay. Capped at the maximum repayable debt
    /// (mininimum of the bundler's balance and the initiator's debt).
    /// @param interestRateMode The interest rate mode of the position.
    function aaveV3Repay(address token, uint256 amount, uint256 interestRateMode) external hubOnly {
        amount = Math.min(amount, ERC20(token).balanceOf(address(this)));

        require(amount != 0, ErrorsLib.ZeroAmount());

        BundlerLib.approveMaxTo(token, address(AAVE_V3_POOL));

        AAVE_V3_POOL.repay(token, amount, interestRateMode, initiator());
    }

    /// @notice Withdraws `amount` of `token` on AaveV3, on behalf of the initiator.
    /// @notice Withdrawn tokens are received by `receiver`
    /// @dev Initiator must have previously transferred their aTokens to the bundler.
    /// @param token The address of the token to withdraw.
    /// @param amount The amount of `token` to withdraw. Pass `type(uint256).max` to withdraw all.
    /// @param receiver The account receiving the withdrawn tokens.
    function aaveV3Withdraw(address token, uint256 amount, address receiver) external hubOnly {
        AAVE_V3_POOL.withdraw(token, amount, receiver);
    }
}
