// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {ERC20Wrapper} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import {CoreAdapter, ErrorsLib, IERC20, SafeERC20} from "./CoreAdapter.sol";

/// @custom:security-contact security@morpho.org
/// @notice Adapter for ERC20Wrapper functions, in particular permissioned wrappers.
contract ERC20WrapperAdapter is CoreAdapter {
    /* CONSTRUCTOR */

    /// @param bundler3 The address of the Bundler3 contract.
    constructor(address bundler3) CoreAdapter(bundler3) {}

    /* ERC20 WRAPPER ACTIONS */

    // Enables the wrapping and unwrapping of ERC20 tokens. The largest usecase is to wrap permissionless tokens to
    // their permissioned counterparts and access permissioned markets on Morpho.

    /// @notice Wraps underlying tokens to wrapped token and sends them to the initiator.
    /// @dev Underlying tokens must have been previously sent to the adapter.
    /// @dev Assumes that `wrapper` implements the `ERC20Wrapper` interface.
    /// @dev The account is hardcoded to the initiator to prevent unauthorized wrapping by mistake.
    /// @param wrapper The address of the ERC20 wrapper contract.
    /// @param amount The amount of underlying tokens to deposit. Pass `type(uint).max` to deposit the adapter's
    /// underlying balance.
    function erc20WrapperDepositFor(address wrapper, uint256 amount) external onlyBundler3 {
        IERC20 underlying = ERC20Wrapper(wrapper).underlying();
        if (amount == type(uint256).max) amount = underlying.balanceOf(address(this));

        require(amount != 0, ErrorsLib.ZeroAmount());

        SafeERC20.forceApprove(underlying, wrapper, type(uint256).max);

        require(ERC20Wrapper(wrapper).depositFor(initiator(), amount), ErrorsLib.DepositFailed());

        SafeERC20.forceApprove(underlying, wrapper, 0);
    }

    /// @notice Unwraps wrapped token to underlying token.
    /// @dev To prevent unauthorized unwrapping, wrapped tokens will be transferred to the initiator then back to the
    /// adapter.
    /// @dev Wrapped tokens must have been previously sent to the adapter.
    /// @dev Assumes that `wrapper` implements the `ERC20Wrapper` interface.
    /// @param wrapper The address of the ERC20 wrapper contract.
    /// @param receiver The address receiving the underlying tokens.
    /// @param amount The amount of wrapped tokens to burn. Pass `type(uint).max` to burn the adapter's wrapped token
    /// balance.
    function erc20WrapperWithdrawTo(address wrapper, address receiver, uint256 amount) external onlyBundler3 {
        require(receiver != address(0), ErrorsLib.ZeroAddress());

        if (amount == type(uint256).max) amount = IERC20(wrapper).balanceOf(address(this));

        require(amount != 0, ErrorsLib.ZeroAmount());

        address initiator = initiator();
        SafeERC20.safeTransfer(IERC20(wrapper), initiator, amount);
        SafeERC20.safeTransferFrom(IERC20(wrapper), initiator, address(this), amount);

        require(ERC20Wrapper(wrapper).withdrawTo(receiver, amount), ErrorsLib.WithdrawFailed());
    }
}
