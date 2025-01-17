// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {ICEth} from "../../interfaces/ICEth.sol";
import {ICToken} from "../../interfaces/ICToken.sol";

import {UtilsLib as MorphoUtilsLib} from "../../../lib/morpho-blue/src/libraries/UtilsLib.sol";
import {MathLib} from "../../../lib/morpho-blue/src/libraries/MathLib.sol";

import {CoreAdapter, ErrorsLib, IERC20, SafeERC20, Address} from "../CoreAdapter.sol";

/// @custom:security-contact security@morpho.org
/// @notice Contract allowing to migrate a position from Compound V2 to Morpho easily.
contract CompoundV2MigrationAdapter is CoreAdapter {
    /* IMMUTABLES */

    /// @dev The address of the cETH contract.
    address public immutable C_ETH;

    /* CONSTRUCTOR */

    /// @param bundler3 The Bundler3 contract address.
    /// @param cEth The address of the cETH contract.
    constructor(address bundler3, address cEth) CoreAdapter(bundler3) {
        require(cEth != address(0), ErrorsLib.ZeroAddress());

        C_ETH = cEth;
    }

    /* ACTIONS */

    /// @notice Repays an ERC20 debt on CompoundV2.
    /// @dev Underlying tokens must have been previously sent to the adapter.
    /// @param cToken The address of the cToken contract.
    /// @param amount The amount of `cToken` to repay. Unlike with `morphoRepay`, the amount is capped at `onBehalf`'s
    /// debt. Pass `type(uint).max` to repay the maximum repayable debt (minimum of the adapter's balance and
    /// `onBehalf`'s debt).
    /// @param onBehalf The account on behalf of which the debt is repaid.
    function compoundV2RepayErc20(address cToken, uint256 amount, address onBehalf) external onlyBundler3 {
        require(cToken != C_ETH, ErrorsLib.CTokenIsCETH());

        address underlying = ICToken(cToken).underlying();

        if (amount == type(uint256).max) amount = IERC20(underlying).balanceOf(address(this));

        amount = MorphoUtilsLib.min(amount, ICToken(cToken).borrowBalanceCurrent(onBehalf));

        require(amount != 0, ErrorsLib.ZeroAmount());

        SafeERC20.forceApprove(IERC20(underlying), cToken, type(uint256).max);

        require(ICToken(cToken).repayBorrowBehalf(onBehalf, amount) == 0, ErrorsLib.RepayError());

        SafeERC20.forceApprove(IERC20(underlying), cToken, 0);
    }

    /// @notice Repays an ETH debt on CompoundV2.
    /// @dev ETH must have been previously sent to the adapter.
    /// @param amount The amount of cEth to repay. Unlike with `morphoRepay`, the amount is capped at `onBehalf`'s debt.
    /// Pass `type(uint).max` to repay the maximum repayable debt (minimum of the adapter's balance and `onBehalf`'s
    /// debt).
    /// @param onBehalf The account on behalf of which the debt is repaid.
    function compoundV2RepayEth(uint256 amount, address onBehalf) external onlyBundler3 {
        if (amount == type(uint256).max) amount = address(this).balance;
        amount = MorphoUtilsLib.min(amount, ICEth(C_ETH).borrowBalanceCurrent(onBehalf));

        require(amount != 0, ErrorsLib.ZeroAmount());

        ICEth(C_ETH).repayBorrowBehalf{value: amount}(onBehalf);
    }

    /// @notice Redeems cToken from CompoundV2.
    /// @dev cTokens must have been previously sent to the adapter.
    /// @param cToken The address of the cToken contract
    /// @param amount The amount of cToken to redeem. Unlike with `morphoWithdraw` using a shares argument, the amount
    /// is capped at the adapter's max redeemable amount. Pass `type(uint).max` to always
    /// redeem the adapter's balance.
    /// @param receiver The account receiving the redeemed assets.
    function compoundV2RedeemErc20(address cToken, uint256 amount, address receiver) external onlyBundler3 {
        require(cToken != C_ETH, ErrorsLib.CTokenIsCETH());

        amount = MorphoUtilsLib.min(amount, ICToken(cToken).balanceOf(address(this)));

        require(amount != 0, ErrorsLib.ZeroAmount());

        uint256 received = MathLib.wMulDown(ICToken(cToken).exchangeRateCurrent(), amount);
        require(ICToken(cToken).redeem(amount) == 0, ErrorsLib.RedeemError());

        if (receiver != address(this)) {
            SafeERC20.safeTransfer(IERC20(ICToken(cToken).underlying()), receiver, received);
        }
    }

    /// @notice Redeems cEth from CompoundV2.
    /// @dev cEth must have been previously sent to the adapter.
    /// @param amount The amount of cEth to redeem. Unlike with `morphoWithdraw` using a shares argument, the amount is
    /// capped at the adapter's max redeemable amount. Pass `type(uint).max` to redeem the adapter's balance.
    /// @param receiver The account receiving the redeemed ETH.
    function compoundV2RedeemEth(uint256 amount, address receiver) external onlyBundler3 {
        amount = MorphoUtilsLib.min(amount, ICEth(C_ETH).balanceOf(address(this)));

        require(amount != 0, ErrorsLib.ZeroAmount());

        uint256 received = MathLib.wMulDown(ICEth(C_ETH).exchangeRateCurrent(), amount);
        require(ICEth(C_ETH).redeem(amount) == 0, ErrorsLib.RedeemError());

        if (receiver != address(this)) Address.sendValue(payable(receiver), received);
    }
}
