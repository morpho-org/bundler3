// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @custom:security-contact security@morpho.org
/// @notice Library exposing error messages.
library ErrorsLib {
    /* STANDARD ADAPTERS */

    /// @dev Thrown when a multicall is attempted while a bundle is already initiated.
    error AlreadyInitiated();

    /// @dev Thrown when a call is attempted from an unauthorized sender.
    error UnauthorizedSender();

    /// @dev Thrown when a reenter is attempted but the concatenation of the sender and bundle does not hash to the
    /// pre-recorded `reenterHash`.
    error IncorrectReenterHash();

    /// @dev Thrown when a multicall is attempted with an empty bundle.
    error EmptyBundle();

    /// @dev Thrown when a reenter was expected but did not happen.
    error MissingExpectedReenter();

    /// @dev Thrown when a call is attempted with a zero address as input.
    error ZeroAddress();

    /// @dev Thrown when a call is attempted with the adapter address as input.
    error AdapterAddress();

    /// @dev Thrown when a call is attempted with a zero amount as input.
    error ZeroAmount();

    /// @dev Thrown when a call is attempted with a zero shares as input.
    error ZeroShares();

    /// @dev Thrown when the given owner is unexpected.
    error UnexpectedOwner();

    /// @dev Thrown when an action ends up minting/burning more shares than a given slippage.
    error SlippageExceeded();

    /// @dev Thrown when a call to depositFor fails.
    error DepositFailed();

    /// @dev Thrown when a call to withdrawTo fails.
    error WithdrawFailed();

    /* MIGRATION ADAPTERS */

    /// @dev Thrown when repaying a CompoundV2 debt returns an error code.
    error RepayError();

    /// @dev Thrown when redeeming CompoundV2 cTokens returns an error code.
    error RedeemError();

    /// @dev Thrown when trying to repay ETH on CompoundV2 with the wrong function.
    error CTokenIsCETH();

    /* PARASWAP ADAPTER */

    /// @dev Thrown when the contract used to trade is not deemed valid by Paraswap's Augustus registry.
    error InvalidAugustus();

    /// @dev Thrown when a data offset is invalid.
    error InvalidOffset();

    /// @dev Thrown when a swap has spent too many source tokens.
    error SellAmountTooHigh();

    /// @dev Thrown when a swap has not bought enough destination tokens.
    error BuyAmountTooLow();
}
