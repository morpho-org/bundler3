// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @dev Thrown when a multicall is attempted while the bundler in an initiated execution context.
error AlreadyInitiated();

/// @dev Thrown when a call is attempted from an unauthorized sender.
error UnauthorizedSender();

/// @dev Thrown when a call is attempted with a zero address as input.
error ZeroAddress();
/// @dev Thrown when a call is attempted with the bundler address as input.
error BundlerAddress();

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

/// @dev Thrown when contract used to trade is not in the paraswap registry.
error AugustusNotInRegistry(address account);

/// @dev Thrown when the selected market does not have the correct loan token.
error IncorrectLoanToken(address token);

/// @dev Thrown when a data offset is invalid.
error InvalidOffset(uint256 offset);

/// @dev Thrown when a swap has spent too many source tokens.
error SellAmountTooHigh(uint256 amount);

/// @dev Thrown when a swap has bought too few destination tokens.
error BuyAmountTooLow(uint256 amount);
