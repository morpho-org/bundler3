// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {CoreAdapter, ErrorsLib, IERC20, SafeERC20} from "./CoreAdapter.sol";
import {ERC20Wrapper} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Wrapper.sol";

/// @custom:security-contact security@morpho.org
/// @notice Permissioned wrapper adapter
contract PermissionedWrapperAdapter is CoreAdapter {

    /* CONSTRUCTOR */

    /// @param bundler3 The address of the Bundler3 contract.
    constructor(address bundler3) CoreAdapter(bundler3) {}

    /* ERC20 PERMISSIONED WRAPPER ACTIONS */

    // Enables the wrapping of ERC20 tokens to their permissioned counterparts.
    // Users can then access thus access permissioned markets on Morpho.
    // Permissioned tokens can be built using: https://github.com/morpho-org/erc20-permissioned

    /// @notice Wraps underlying tokens to wrapped token and send them to the initiator.
    /// @dev Underlying tokens must have been previously sent to the adapter.
    /// @dev Assumes that `wrapper` implements the `ERC20Wrapper` interface.
    /// @param wrapper The address of the ERC20 wrapper contract.
    /// @param amount The amount of underlying tokens to deposit. Pass `type(uint).max` to deposit the adapter's
    /// underlying balance.
    function erc20PermissionedWrapperDeposit(address wrapper, uint256 amount) external onlyBundler3 {
        IERC20 underlying = ERC20Wrapper(wrapper).underlying();
        if (amount == type(uint256).max) amount = underlying.balanceOf(address(this));

        require(amount != 0, ErrorsLib.ZeroAmount());

        SafeERC20.forceApprove(underlying, wrapper, type(uint256).max);

        require(ERC20Wrapper(wrapper).depositFor(initiator(), amount), ErrorsLib.DepositFailed());

        SafeERC20.forceApprove(underlying, wrapper, 0);
    }

    /// @notice Unwraps wrapped token to underlying token.
    /// @notice Duplicates the functionality of GeneralAdapter1.erc20WrapperWithdrawTo because permissioned tokens will not whitelist the GeneralAdapter1.
    /// @dev Wrapped tokens must have been previously sent to the adapter.
    /// @dev Assumes that `wrapper` implements the `ERC20Wrapper` interface.
    /// @param wrapper The address of the ERC20 wrapper contract.
    /// @param receiver The address receiving the underlying tokens.
    /// @param amount The amount of wrapped tokens to burn. Pass `type(uint).max` to burn the adapter's wrapped token
    /// balance.
    function erc20PermissionedWrapperWithdrawTo(address wrapper, address receiver, uint256 amount) external onlyBundler3 {
        require(receiver != address(0), ErrorsLib.ZeroAddress());

        if (amount == type(uint256).max) amount = IERC20(wrapper).balanceOf(address(this));

        require(amount != 0, ErrorsLib.ZeroAmount());

        require(ERC20Wrapper(wrapper).withdrawTo(receiver, amount), ErrorsLib.WithdrawFailed());
    }
}
