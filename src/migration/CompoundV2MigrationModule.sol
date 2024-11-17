// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {ICEth} from "./interfaces/ICEth.sol";
import {ICToken} from "./interfaces/ICToken.sol";

import {Math} from "../../lib/morpho-utils/src/math/Math.sol";
import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {MathLib} from "../../lib/morpho-blue/src/libraries/MathLib.sol";

import {BaseModule, ERC20, SafeTransferLib, ModuleLib} from "../BaseModule.sol";

/// @title CompoundV2MigrationModule
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Contract allowing to migrate a position from Compound V2 to Morpho Blue easily.
contract CompoundV2MigrationModule is BaseModule {
    /* IMMUTABLES */

    /// @dev The address of the cETH contract.
    address public immutable C_ETH;

    /* CONSTRUCTOR */

    /// @param bundler The Bundler contract address
    /// @param cEth The address of the cETH contract.
    constructor(address bundler, address cEth) BaseModule(bundler) {
        require(cEth != address(0), ErrorsLib.ZeroAddress());

        C_ETH = cEth;
    }

    /* ACTIONS */

    /// @notice Repays `amount` of `cToken`'s underlying asset, on behalf of the initiator.
    /// @dev Underlying tokens must have been previously sent to the module.
    /// @param cToken The address of the cToken contract.
    /// @param amount The amount of `cToken` to repay. Pass max to repay the maximum repayable debt (mininimum of the
    /// module's balance and the initiator's debt).
    function compoundV2Repay(address cToken, uint256 amount) external bundlerOnly {
        address _initiator = initiator();

        if (cToken == C_ETH) {
            if (amount == type(uint256).max) {
                amount = Math.min(address(this).balance, ICEth(C_ETH).borrowBalanceCurrent(_initiator));
            }

            require(amount != 0, ErrorsLib.ZeroAmount());

            ICEth(C_ETH).repayBorrowBehalf{value: amount}(_initiator);
        } else {
            address underlying = ICToken(cToken).underlying();

            if (amount == type(uint256).max) {
                amount = Math.min(
                    ERC20(underlying).balanceOf(address(this)), ICToken(cToken).borrowBalanceCurrent(_initiator)
                );
            }

            require(amount != 0, ErrorsLib.ZeroAmount());

            ModuleLib.approveMaxToIfAllowanceZero(underlying, cToken);

            require(ICToken(cToken).repayBorrowBehalf(_initiator, amount) == 0, ErrorsLib.RepayError());
        }
    }

    /// @notice Redeems `amount` of `cToken` from CompoundV2.
    /// @dev cTokens must have been previously sent to the module.
    /// @param cToken The address of the cToken contract
    /// @param amount The amount of `cToken` to redeem. Pass max to redeem the module's `cToken` balance.
    /// @param receiver The account receiving the redeemed assets.
    function compoundV2Redeem(address cToken, uint256 amount, address receiver) external bundlerOnly {
        if (amount == type(uint256).max) amount = ICToken(cToken).balanceOf(address(this));

        require(amount != 0, ErrorsLib.ZeroAmount());

        uint256 received = MathLib.wMulDown(ICToken(cToken).exchangeRateCurrent(), amount);
        require(ICToken(cToken).redeem(amount) == 0, ErrorsLib.RedeemError());

        if (receiver != address(this)) {
            if (cToken == C_ETH) {
                SafeTransferLib.safeTransferETH(receiver, received);
            } else {
                SafeTransferLib.safeTransfer(ERC20(ICToken(cToken).underlying()), receiver, received);
            }
        }
    }
}
