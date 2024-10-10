// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {Math} from "../lib/morpho-utils/src/math/Math.sol";
import {SafeTransferLib, ERC20} from "../lib/solmate/src/utils/SafeTransferLib.sol";

import {BaseBundler} from "./BaseBundler.sol";
import {ERC20Wrapper} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Wrapper.sol";

/// @title ERC20WrapperBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Enables the wrapping and unwrapping of ERC20 tokens. The largest usecase is to wrap permissionless tokens to
/// their permissioned counterparts and access permissioned markets on Morpho Blue. Permissioned tokens can be built
/// using: https://github.com/morpho-org/erc20-permissioned
abstract contract ERC20WrapperBundler is BaseBundler {
    using SafeTransferLib for ERC20;

    /* WRAPPER ACTIONS */

    /// @notice Deposits underlying tokens and mints the corresponding amount of wrapped tokens to the initiator.
    /// @dev Wraps tokens on behalf of the initiator to make sure they are able to receive and transfer wrapped tokens.
    /// @dev Wrapped tokens must be transferred to the bundler afterwards to perform additional actions.
    /// @dev Initiator must have previously transferred their tokens to the bundler.
    /// @dev Assumes that `wrapper` implements the `ERC20Wrapper` interface and that the `depositFor` function returns a
    /// boolean.
    /// @param wrapper The address of the ERC20 wrapper contract.
    /// @param amount The amount of underlying tokens to deposit. Capped at the bundler's balance.
    function erc20WrapperDepositFor(address wrapper, uint256 amount) external payable protected {
        ERC20 underlying = ERC20(address(ERC20Wrapper(wrapper).underlying()));

        amount = Math.min(amount, underlying.balanceOf(address(this)));

        require(amount != 0, ErrorsLib.ZERO_AMOUNT);

        _approveMaxTo(address(underlying), wrapper);

        require(ERC20Wrapper(wrapper).depositFor(initiator, amount), ErrorsLib.DEPOSIT_FAILED);
    }

    /// @notice Burns a number of wrapped tokens and withdraws the corresponding number of underlying tokens.
    /// @dev Initiator must have previously transferred their wrapped tokens to the bundler.
    /// @dev Assumes that `wrapper` implements the `ERC20Wrapper` interface and that the `withdrawTo` function returns a
    /// boolean.
    /// @param wrapper The address of the ERC20 wrapper contract.
    /// @param account The address receiving the underlying tokens.
    /// @param amount The amount of wrapped tokens to burn. Capped at the bundler's balance.
    function erc20WrapperWithdrawTo(address wrapper, address account, uint256 amount) external payable protected {
        require(account != address(0), ErrorsLib.ZERO_ADDRESS);

        amount = Math.min(amount, ERC20(wrapper).balanceOf(address(this)));

        require(amount != 0, ErrorsLib.ZERO_AMOUNT);

        require(ERC20Wrapper(wrapper).withdrawTo(account, amount), ErrorsLib.WITHDRAW_FAILED);
    }
}
