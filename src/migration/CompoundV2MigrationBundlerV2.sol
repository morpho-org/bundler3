// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {ICEth} from "./interfaces/ICEth.sol";
import {ICToken} from "./interfaces/ICToken.sol";

import {Math} from "../../lib/morpho-utils/src/math/Math.sol";
import {ErrorsLib} from "../libraries/ErrorsLib.sol";

import {BaseBundler} from "../BaseBundler.sol";
import {ERC20} from "./MigrationBundler.sol";
import {BundlerLib} from "../libraries/BundlerLib.sol";
import "forge-std/console.sol";

/// @title CompoundV2MigrationBundlerV2
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Contract allowing to migrate a position from Compound V2 to Morpho Blue easily.
contract CompoundV2MigrationBundlerV2 is BaseBundler {
    /* IMMUTABLES */

    /// @dev The address of the cETH contract.
    address public immutable C_ETH;

    /* CONSTRUCTOR */

    /// @param hub The Hub contract address
    /// @param cEth The address of the cETH contract.
    constructor(address hub, address cEth) BaseBundler(hub) {
        require(cEth != address(0), ErrorsLib.ZeroAddress());

        C_ETH = cEth;
    }

    /* ACTIONS */

    /// @notice Repays `amount` of `cToken`'s underlying asset, on behalf of the initiator.
    /// @dev Initiator must have previously transferred their assets to the bundler.
    /// @param cToken The address of the cToken contract.
    /// @param amount The amount of `cToken` to repay. Capped at the maximum repayable debt
    /// (mininimum of the bundler's balance and the initiator's debt).
    function compoundV2Repay(address cToken, uint256 amount) external hubOnly {
        address _initiator = initiator();

        if (cToken == C_ETH) {
            amount = Math.min(amount, address(this).balance);
            amount = Math.min(amount, ICEth(C_ETH).borrowBalanceCurrent(_initiator));

            require(amount != 0, ErrorsLib.ZeroAmount());

            ICEth(C_ETH).repayBorrowBehalf{value: amount}(_initiator);
        } else {
            address underlying = ICToken(cToken).underlying();

            amount = Math.min(amount, ERC20(underlying).balanceOf(address(this)));
            amount = Math.min(amount, ICToken(cToken).borrowBalanceCurrent(_initiator));

            require(amount != 0, ErrorsLib.ZeroAmount());

            BundlerLib.approveMaxTo(underlying, cToken);

            require(ICToken(cToken).repayBorrowBehalf(_initiator, amount) == 0, ErrorsLib.RepayError());
        }
    }

    /// @notice Redeems `amount` of `cToken` from CompoundV2.
    /// @notice Withdrawn assets are received `receiver`.
    /// @dev Initiator must have previously transferred their cTokens to the bundler.
    /// @param cToken The address of the cToken contract
    /// @param amount The amount of `cToken` to redeem. Pass `type(uint256).max` to redeem the bundler's `cToken`
    /// balance.
    /// @param receiver The account receiving the redeemed assets.
    function compoundV2Redeem(address cToken, uint256 amount, address receiver) external hubOnly {
        amount = Math.min(amount, ERC20(cToken).balanceOf(address(this)));

        require(amount != 0, ErrorsLib.ZeroAmount());

        require(ICToken(cToken).redeem(amount) == 0, ErrorsLib.RedeemError());

        if (cToken == C_ETH) {
            BundlerLib.nativeTransfer(receiver, address(this).balance);
        } else {
            address underlying = ICToken(cToken).underlying();
            BundlerLib.erc20Transfer(underlying, receiver, ERC20(underlying).balanceOf(address(this)));
        }
    }
}
