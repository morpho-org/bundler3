// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IAaveV2} from "../../interfaces/IAaveV2.sol";

import {ErrorsLib} from "../../libraries/ErrorsLib.sol";

import {CoreAdapter} from "../CoreAdapter.sol";
import {ERC20} from "../../../lib/solmate/src/utils/SafeTransferLib.sol";
import {UtilsLib} from "../../libraries/UtilsLib.sol";

/// @custom:contact security@morpho.org
/// @notice Contract allowing to migrate a position from Aave V2 to Morpho Blue easily.
contract AaveV2MigrationAdapter is CoreAdapter {
    /* IMMUTABLES */

    /// @dev The AaveV2 contract address.
    IAaveV2 public immutable AAVE_V2_POOL;

    /* CONSTRUCTOR */

    /// @param multiexec The Multiexec contract address
    /// @param aaveV2Pool The AaveV2 contract address.
    constructor(address multiexec, address aaveV2Pool) CoreAdapter(multiexec) {
        require(aaveV2Pool != address(0), ErrorsLib.ZeroAddress());

        AAVE_V2_POOL = IAaveV2(aaveV2Pool);
    }

    /* ACTIONS */

    /// @notice Repays debt on AaveV2.
    /// @dev Underlying tokens must have been previously sent to the adapter.
    /// @param token The address of the token to repay.
    /// @param amount The amount of `token` to repay. Unlike with `morphoRepay`, the amount is capped at `onBehalf`'s
    /// debt. Pass `type(uint).max` to repay the maximum repayable debt (minimum of the adapter's balance and
    /// `onBehalf`'s debt).
    /// @param interestRateMode The interest rate mode of the position.
    /// @param onBehalf The account on behalf of which the debt is repaid.
    function aaveV2Repay(address token, uint256 amount, uint256 interestRateMode, address onBehalf)
        external
        onlyMultiexec
    {
        // Amount will be capped at `onBehalf`'s debt by Aave.
        if (amount == type(uint256).max) amount = ERC20(token).balanceOf(address(this));

        require(amount != 0, ErrorsLib.ZeroAmount());

        UtilsLib.approveMaxToIfAllowanceZero(token, address(AAVE_V2_POOL));

        AAVE_V2_POOL.repay(token, amount, interestRateMode, onBehalf);
    }

    /// @notice Withdraws on AaveV2.
    /// @dev aTokens must have been previously sent to the adapter.
    /// @param token The address of the token to withdraw.
    /// @param amount The amount of `token` to withdraw. Unlike with `morphoWithdraw`, the amount is capped at the
    /// initiator's max withdrawable amount. Pass
    /// `type(uint).max` to always withdraw all.
    /// @param receiver The account receiving the withdrawn tokens.
    function aaveV2Withdraw(address token, uint256 amount, address receiver) external onlyMultiexec {
        require(amount != 0, ErrorsLib.ZeroAmount());

        AAVE_V2_POOL.withdraw(token, amount, receiver);
    }
}
