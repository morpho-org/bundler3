// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @title ErrorsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing error messages.
library ErrorsLib {
    /// @dev Thrown when a multicall is attempted while the bundler in an initiated execution context.
    error AlreadyInitiated();

    /// @dev Thrown when a call is attempted from an unauthorized sender.
    error UnauthorizedSender(address sender);

    /// @dev Thrown when a call is attempted with a zero address as input.
    error ZeroAddress();

    /// @dev Thrown when a call is attempted with the bundler address as input.
    error BundlerAddress();

    /// @dev Thrown when a call is attempted with a zero amount as input.
    error ZeroAmount();

    /// @dev Thrown when a call is attempted with a zero shares as input.
    error ZeroShares();

    /// @dev Thrown when the given owner is unexpected.
    error UnexpectedOwner(address account);

    /// @dev Thrown when an action ends up minting/burning more shares than a given slippage.
    error SlippageExceeded();

    /// @dev Thrown when a call to depositFor fails.
    error DepositFailed();

    /// @dev Thrown when a call to withdrawTo fails.
    error WithdrawFailed();
}
