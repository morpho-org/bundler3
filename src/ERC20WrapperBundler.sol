// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {Math} from "../lib/morpho-utils/src/math/Math.sol";
import {ERC20} from "../lib/solmate/src/utils/SafeTransferLib.sol";

import {BaseBundler} from "./BaseBundler.sol";
import {ERC20Wrapper} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import {BundlerLib} from "./libraries/BundlerLib.sol";

/// @title ERC20WrapperBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Enables the wrapping and unwrapping of ERC20 tokens. The largest usecase is to wrap permissionless tokens to
/// their permissioned counterparts and access permissioned markets on Morpho Blue. Permissioned tokens can be built
/// using: https://github.com/morpho-org/erc20-permissioned
abstract contract ERC20WrapperBundler is BaseBundler {
    /* WRAPPER ACTIONS */

    /// @notice Deposits underlying tokens and mints the corresponding amount of wrapped tokens to the initiator.
    /// @dev Wraps tokens on behalf of the initiator to make sure they are able to receive and transfer wrapped tokens.
    /// @dev Wrapped tokens must be transferred to the bundler afterwards to perform additional actions.
    /// @dev Initiator must have previously transferred their tokens to the bundler.
    /// @dev Assumes that `wrapper` implements the `ERC20Wrapper` interface and that the `depositFor` function returns a
    /// @dev Assumes that the ERC20Wrapper wraps tokens 1:1.
    /// boolean.
    /// @param wrapper The address of the ERC20 wrapper contract.
    /// @param receiver The account receiving the wrapped tokens.
    /// @param amount The amount of underlying tokens to deposit. Capped at the bundler's balance.
    function erc20WrapperDepositFor(address wrapper, address receiver, uint256 amount) external hubOnly {
        ERC20 underlying = ERC20(address(ERC20Wrapper(wrapper).underlying()));

        amount = Math.min(amount, underlying.balanceOf(address(this)));

        require(amount != 0, ErrorsLib.ZeroAmount());

        BundlerLib.approveMaxTo(address(underlying), wrapper);

        require(ERC20Wrapper(wrapper).depositFor(receiver, amount), ErrorsLib.DepositFailed());
    }

    /// @notice Burns a number of wrapped tokens and withdraws the corresponding number of underlying tokens.
    /// @dev Initiator must have previously transferred their wrapped tokens to the bundler.
    /// @dev Assumes that `wrapper` implements the `ERC20Wrapper` interface and that the `withdrawTo` function returns a
    /// boolean.
    /// @param wrapper The address of the ERC20 wrapper contract.
    /// @param receiver The address receiving the underlying tokens.
    /// @param amount The amount of wrapped tokens to burn. Capped at the bundler's balance.
    function erc20WrapperWithdrawTo(address wrapper, address receiver, uint256 amount) external hubOnly {
        require(receiver != address(0), ErrorsLib.ZeroAddress());

        amount = Math.min(amount, ERC20(wrapper).balanceOf(address(this)));

        require(amount != 0, ErrorsLib.ZeroAmount());

        require(ERC20Wrapper(wrapper).withdrawTo(receiver, amount), ErrorsLib.WithdrawFailed());
    }
}
