// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {ERC20Wrapper} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import {CoreAdapter, ErrorsLib, IERC20, SafeERC20} from "./CoreAdapter.sol";

/// @custom:security-contact security@morpho.org
/// @notice Adapter for ERC20Wrapper functions, in particular permissioned wrappers.
contract ERC20WrapperAdapter is CoreAdapter {
    /// @notice The address of GeneralAdapter1, only authorized erc20 transfer target.
    address public immutable GENERAL_ADAPTER_1;

    /* CONSTRUCTOR */

    /// @param bundler3 The address of the Bundler3 contract.
    constructor(address bundler3, address generalAdapter1) CoreAdapter(bundler3) {
        require(generalAdapter1 != address(0), ErrorsLib.ZeroAddress());
        GENERAL_ADAPTER_1 = generalAdapter1;
    }

    /* ERC20 WRAPPER ACTIONS */

    // Enables the wrapping and unwrapping of ERC20 tokens. The largest usecase is to wrap permissionless tokens to
    // their permissioned counterparts and access permissioned markets on Morpho. Permissioned tokens can be built
    // using: https://github.com/morpho-org/erc20-permissioned

    /// @notice Wraps underlying tokens to wrapped token and sends them to the initiator.
    /// @dev Underlying tokens must have been previously sent to the adapter.
    /// @dev Assumes that `wrapper` implements the `ERC20Wrapper` interface.
    /// @dev The account is hardcoded to the initiator to prevent unauthorized wrapping.
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
    /// @dev Wrapped tokens will be transferred from the initiator to the adapter. For permissioned tokens, this checks
    /// the whitelisted status of the initiator.
    /// @dev Assumes that `wrapper` implements the `ERC20Wrapper` interface.
    /// @param wrapper The address of the ERC20 wrapper contract.
    /// @param receiver The address receiving the underlying tokens.
    /// @param amount The amount of wrapped tokens to burn. Pass `type(uint).max` to burn the initiator's wrapped token
    /// balance.
    function erc20WrapperWithdrawTo(address wrapper, address receiver, uint256 amount) external onlyBundler3 {
        require(receiver != address(0), ErrorsLib.ZeroAddress());

        address initiator = initiator();

        if (amount == type(uint256).max) amount = IERC20(wrapper).balanceOf(initiator);

        require(amount != 0, ErrorsLib.ZeroAmount());

        SafeERC20.safeTransferFrom(IERC20(wrapper), initiator, address(this), amount);

        require(ERC20Wrapper(wrapper).withdrawTo(receiver, amount), ErrorsLib.WithdrawFailed());
    }

    /* ERC20 ACTIONS */

    /// @inheritdoc CoreAdapter
    function erc20Transfer(address token, address receiver, uint256 amount) public override onlyBundler3 {
        require(receiver == GENERAL_ADAPTER_1, ErrorsLib.UnauthorizedReceiver());
        super.erc20Transfer(token, receiver, amount);
    }
}
